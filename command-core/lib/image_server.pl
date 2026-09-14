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

$SIG{PIPE} = 'IGNORE';

my $host = '127.0.0.1';
my $port = 9933;
my $max_body_bytes = 64 * 1024;
my ($sd_binary, $models_directory, $output_directory) = @ARGV;
die "usage: image_server.pl <sd-cli> <models-directory> <output-directory>\n"
    unless defined($output_directory);

die "image-generation binary not found: $sd_binary\n" unless -f $sd_binary;
die "image model directory not found: $models_directory\n" unless -d $models_directory;
make_path($output_directory) unless -d $output_directory;

my (%models, $default_model);

sub discover_models {
    %models = ();
    my $z_image_directory = "$models_directory/z-image-turbo";
    my $z_image_vae = "$z_image_directory/ae.safetensors";
    my $z_image_llm = "$z_image_directory/Qwen3-4B-Instruct-2507-Q4_K_M.gguf";
    if (-f $z_image_vae && -f $z_image_llm) {
        for my $diffusion_model (glob("$z_image_directory/z_image_turbo-*.gguf")) {
            my $name = basename($diffusion_model);
            $models{"z-image-turbo/$name"} = {
                label => "Z-Image Turbo / $name",
                arguments => ['--diffusion-model', $diffusion_model, '--vae', $z_image_vae, '--llm', $z_image_llm],
                steps => 8,
            };
        }
    }

    my $flux_directory = "$models_directory/flux1-schnell";
    my $flux_vae = "$flux_directory/ae.safetensors";
    my $flux_clip = "$flux_directory/clip_l.safetensors";
    my $flux_t5 = "$flux_directory/t5xxl_fp16.safetensors";
    if (-f $flux_vae && -f $flux_clip && -f $flux_t5) {
        for my $diffusion_model (glob("$flux_directory/flux1-schnell-*.gguf")) {
            my $name = basename($diffusion_model);
            $models{"flux1-schnell/$name"} = {
                label => "FLUX.1 Schnell / $name",
                arguments => [
                    '--diffusion-model', $diffusion_model, '--vae', $flux_vae,
                    '--clip_l', $flux_clip, '--t5xxl', $flux_t5,
                    '--sampling-method', 'euler', '--clip-on-cpu',
                    '--params-backend', 'te=disk',
                    '--guidance', '0',
                ],
                steps => 4,
            };
        }
    }

    die "no complete image model bundles found below $models_directory\n" unless keys %models;
    ($default_model) = sort { ($a !~ /^z-image-turbo\//) <=> ($b !~ /^z-image-turbo\//) || $a cmp $b } keys %models;
}

discover_models();

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
    discover_models();
    my $prompt = $payload->{prompt};
    die "prompt must be a non-empty string\n"
        unless defined($prompt) && !ref($prompt) && $prompt =~ /\S/ && length(encode('UTF-8', $prompt)) <= 8 * 1024;

    my $width = bounded_integer($payload->{width}, 1024, 256, 2048, 'width');
    my $height = bounded_integer($payload->{height}, 1024, 256, 2048, 'height');
    my $model = $payload->{model} // $default_model;
    die "unknown image model\n" unless !ref($model) && exists $models{$model};
    my $steps = bounded_integer($payload->{steps}, $models{$model}{steps}, 1, 50, 'steps');
    die "width and height must be multiples of 64\n" if $width % 64 || $height % 64;

    my $seed = defined($payload->{seed}) ? bounded_integer($payload->{seed}, 0, 0, 2147483647, 'seed') : int(rand(2147483647));
    my $filename = strftime('z-image-%Y%m%d-%H%M%S', localtime) . "-$seed.png";
    my $output_path = "$output_directory/$filename";
    my @arguments = (
        $sd_binary,
        @{$models{$model}{arguments}},
        '--prompt', $prompt,
        '--cfg-scale', '1.0',
        '--steps', $steps,
        '--width', $width,
        '--height', $height,
        '--seed', $seed,
        '--output', $output_path,
        '--diffusion-fa',
        '--vae-tiling',
    );
    push @arguments, '--offload-to-cpu' if $payload->{offloadToCpu};

    pipe my $reader, my $writer or die "cannot create sd-cli output pipe: $!\n";
    my $process_id = fork();
    die "cannot start sd-cli: $!\n" unless defined $process_id;
    if ($process_id == 0) {
        close $reader;
        open STDOUT, '>&', $writer or exit 127;
        open STDERR, '>&', $writer or exit 127;
        close $writer;
        exec {$arguments[0]} @arguments or exit 127;
    }
    close $writer;
    local $/;
    my $log = <$reader> // '';
    close $reader;
    waitpid $process_id, 0;
    my $exit_code = $? & 127 ? 128 + ($? & 127) : $? >> 8;
    die "image generation failed: FLUX text encoder could not be loaded\n"
        if $log =~ /t5xxl (?:text encoder not found|from .* failed)/i;
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
            send_json($client, 200, { status => 'ready', model => $default_model });
        } elsif ($method eq 'GET' && $path eq '/models') {
            discover_models();
            send_json($client, 200, {
                default => $default_model,
                models => [map {
                    { id => $_, label => $models{$_}{label}, steps => $models{$_}{steps} }
                } sort keys %models],
            });
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