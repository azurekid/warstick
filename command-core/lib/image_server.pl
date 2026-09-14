#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use Encode qw(encode);
use File::Basename qw(basename);
use File::Path qw(make_path);
use IO::Socket::INET;
use JSON::PP;
use POSIX qw(strftime);

my $host = '127.0.0.1';
my $port = 9933;
my $max_body_bytes = 64 * 1024;
my ($sd_binary, $diffusion_model, $vae_model, $llm_model, $output_directory) = @ARGV;
die "usage: image_server.pl <sd-cli> <diffusion-model> <vae> <llm> <output-directory>\n"
    unless defined($output_directory);

for my $path ($sd_binary, $diffusion_model, $vae_model, $llm_model) {
    die "required image-generation file not found: $path\n" unless -f $path;
}
make_path($output_directory) unless -d $output_directory;

my $json = JSON::PP->new->utf8->canonical;

sub send_response {
    my ($client, $status, $content_type, $body) = @_;
    my %reasons = (200 => 'OK', 204 => 'No Content', 400 => 'Bad Request', 404 => 'Not Found', 500 => 'Internal Server Error');
    $body //= '';
    print {$client} "HTTP/1.1 $status $reasons{$status}\r\n";
    print {$client} "Content-Type: $content_type\r\n";
    print {$client} 'Content-Length: ' . length($body) . "\r\n";
    print {$client} "Access-Control-Allow-Origin: http://127.0.0.1:9931\r\n";
    print {$client} "Access-Control-Allow-Methods: GET, POST, OPTIONS\r\n";
    print {$client} "Access-Control-Allow-Headers: Content-Type\r\n";
    print {$client} "Cache-Control: no-store\r\n";
    print {$client} "Connection: close\r\n\r\n";
    print {$client} $body if length($body);
}

sub send_json {
    my ($client, $status, $payload) = @_;
    send_response($client, $status, 'application/json; charset=utf-8', $status == 204 ? '' : $json->encode($payload));
}

sub bounded_integer {
    my ($value, $default, $minimum, $maximum, $name) = @_;
    $value = $default unless defined $value;
    die "$name must be an integer between $minimum and $maximum\n"
        unless !ref($value) && "$value" =~ /^\d+$/ && $value >= $minimum && $value <= $maximum;
    return int($value);
}

sub generate_image {
    my ($payload) = @_;
    my $prompt = $payload->{prompt};
    die "prompt must be a non-empty string\n"
        unless defined($prompt) && !ref($prompt) && $prompt =~ /\S/ && length(encode('UTF-8', $prompt)) <= 8 * 1024;

    my $width = bounded_integer($payload->{width}, 1024, 256, 2048, 'width');
    my $height = bounded_integer($payload->{height}, 1024, 256, 2048, 'height');
    my $steps = bounded_integer($payload->{steps}, 8, 1, 50, 'steps');
    die "width and height must be multiples of 64\n" if $width % 64 || $height % 64;

    my $seed = defined($payload->{seed}) ? bounded_integer($payload->{seed}, 0, 0, 2147483647, 'seed') : int(rand(2147483647));
    my $filename = strftime('z-image-%Y%m%d-%H%M%S', localtime) . "-$seed.png";
    my $output_path = "$output_directory/$filename";
    my @arguments = (
        $sd_binary,
        '--diffusion-model', $diffusion_model,
        '--vae', $vae_model,
        '--llm', $llm_model,
        '--prompt', $prompt,
        '--cfg-scale', '1.0',
        '--steps', $steps,
        '--width', $width,
        '--height', $height,
        '--seed', $seed,
        '--output', $output_path,
        '--diffusion-fa',
    );
    push @arguments, '--offload-to-cpu' if $payload->{offloadToCpu};

    open my $process, '-|', @arguments or die "cannot start sd-cli: $!\n";
    local $/;
    my $log = <$process> // '';
    close $process;
    my $exit_code = $? >> 8;
    die "image generation failed (exit $exit_code): " . substr($log, -2000) . "\n"
        if $exit_code != 0 || !-f $output_path;

    return { imageUrl => "http://127.0.0.1:$port/images/$filename", filename => $filename, seed => $seed };
}

my $server = IO::Socket::INET->new(
    LocalAddr => $host,
    LocalPort => $port,
    Proto => 'tcp',
    Listen => 5,
    ReuseAddr => 1,
) or die "cannot listen on $host:$port: $!\n";

while (my $client = $server->accept()) {
    binmode $client, ':raw';
    $client->autoflush(1);
    eval {
        my $request_line = <$client> // die "empty request\n";
        $request_line =~ s/\r?\n$//;
        my ($method, $path) = split /\s+/, $request_line;
        my $content_length = 0;
        while (my $header = <$client>) {
            last if $header eq "\r\n" || $header eq "\n";
            $content_length = $1 if $header =~ /^Content-Length:\s*(\d+)/i;
        }

        if ($method eq 'OPTIONS') {
            send_json($client, 204, {});
        } elsif ($method eq 'GET' && $path eq '/health') {
            send_json($client, 200, { status => 'ready' });
        } elsif ($method eq 'GET' && $path =~ m{^/images/([^/]+\.png)$}) {
            my $filename = basename($1);
            my $image_path = "$output_directory/$filename";
            if (-f $image_path) {
                open my $image, '<:raw', $image_path or die "cannot read image: $!\n";
                local $/;
                send_response($client, 200, 'image/png', <$image>);
                close $image;
            } else {
                send_json($client, 404, { error => 'image not found' });
            }
        } elsif ($method eq 'POST' && $path eq '/generate') {
            die "invalid request size\n" if $content_length <= 0 || $content_length > $max_body_bytes;
            my $body = '';
            while (length($body) < $content_length) {
                my $count = read $client, my $chunk, $content_length - length($body);
                die "incomplete request body\n" unless $count;
                $body .= $chunk;
            }
            send_json($client, 200, generate_image($json->decode($body)));
        } else {
            send_json($client, 404, { error => 'not found' });
        }
        1;
    } or do {
        my $error = $@ || 'request failed';
        $error =~ s/\s+$//;
        eval { send_json($client, 400, { error => $error }); };
    };
    close $client;
}