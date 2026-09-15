#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use Encode qw(decode encode);
use File::Basename qw(dirname);
use File::Path qw(make_path);
use File::Temp qw(tempfile);
use IO::Socket::INET;
use JSON::PP;

my $host = '127.0.0.1';
my $port = 9932;
my $max_body_bytes = 5 * 1024 * 1024;
my $history_file = shift @ARGV or die "usage: history_server.pl <history-file>\n";
my $json = JSON::PP->new->utf8->canonical->pretty;

sub validate_messages {
    my ($value) = @_;
    die "messages must be an array\n" unless ref($value) eq 'ARRAY';

    my @messages;
    for my $item (@{$value}) {
        die "each message must be an object\n" unless ref($item) eq 'HASH';
        my $role = $item->{role};
        my $content = $item->{content};
        die "each message needs a valid role and string content\n"
            unless defined($role)
                && ($role eq 'user' || $role eq 'assistant')
                && defined($content)
                && !ref($content);
        push @messages, { role => $role, content => $content };
    }
    return \@messages;
}

sub validate_war_mode {
    my ($value) = @_;
    return JSON::PP::false unless defined $value;
    die "warMode must be a boolean\n" unless JSON::PP::is_bool($value);
    return $value ? JSON::PP::true : JSON::PP::false;
}

sub response {
    my ($client, $status, $payload) = @_;
    my %reasons = (200 => 'OK', 204 => 'No Content', 400 => 'Bad Request', 404 => 'Not Found', 500 => 'Internal Server Error');
    my $body = $status == 204 ? '' : $json->encode($payload);
    print {$client} "HTTP/1.1 $status $reasons{$status}\r\n";
    print {$client} "Content-Type: application/json; charset=utf-8\r\n";
    print {$client} 'Content-Length: ' . length($body) . "\r\n";
    print {$client} "Access-Control-Allow-Origin: http://127.0.0.1:9931\r\n";
    print {$client} "Access-Control-Allow-Methods: GET, PUT, DELETE, OPTIONS\r\n";
    print {$client} "Access-Control-Allow-Headers: Content-Type\r\n";
    print {$client} "Cache-Control: no-store\r\n";
    print {$client} "Connection: close\r\n\r\n";
    print {$client} $body if length($body);
}

sub read_history {
    return { messages => [], warMode => JSON::PP::false } unless -f $history_file;
    open my $file, '<:raw', $history_file or die "cannot read history: $!\n";
    local $/;
    my $payload = $json->decode(<$file>);
    close $file;
    return {
        messages => validate_messages($payload->{messages}),
        warMode => validate_war_mode($payload->{warMode}),
    };
}

sub save_history {
    my ($messages, $war_mode) = @_;
    my $directory = dirname($history_file);
    make_path($directory) unless -d $directory;
    my ($temporary, $temporary_name) = tempfile('chat_history.XXXXXX', DIR => $directory, UNLINK => 0);
    binmode $temporary, ':raw';
    print {$temporary} $json->encode({ messages => $messages, warMode => $war_mode });
    close $temporary or die "cannot close temporary history: $!\n";
    rename $temporary_name, $history_file or do {
        unlink $temporary_name;
        die "cannot replace history: $!\n";
    };
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
            response($client, 204, {});
        } elsif ($path ne '/history') {
            response($client, 404, { error => 'not found' });
        } elsif ($method eq 'GET') {
            response($client, 200, read_history());
        } elsif ($method eq 'PUT') {
            die "invalid request size\n" if $content_length <= 0 || $content_length > $max_body_bytes;
            my $body = '';
            while (length($body) < $content_length) {
                my $count = read $client, my $chunk, $content_length - length($body);
                die "incomplete request body\n" unless $count;
                $body .= $chunk;
            }
            my $payload = $json->decode($body);
            my $messages = validate_messages($payload->{messages});
            my $war_mode = validate_war_mode($payload->{warMode});
            save_history($messages, $war_mode);
            response($client, 200, { messages => $messages, warMode => $war_mode });
        } elsif ($method eq 'DELETE') {
            unlink $history_file if -f $history_file;
            response($client, 200, { messages => [], warMode => JSON::PP::false });
        } else {
            response($client, 404, { error => 'not found' });
        }
        1;
    } or do {
        my $error = $@ || 'request failed';
        $error =~ s/\s+$//;
        eval { response($client, 400, { error => $error }); };
    };
    close $client;
}
