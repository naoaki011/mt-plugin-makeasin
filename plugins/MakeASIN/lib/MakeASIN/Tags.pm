package MakeASIN::Tags;
use strict;
use URI::Escape;
use LWP::Simple;
use XML::Simple;

sub isbn_to_asin {
    my ($text, $arg, $ctx) = @_;
    $arg or return $text;
    $text =~ s/[^\d]//g;
    my $len;
    if(($len = length($text)) != 13){
        return $text;
    }

    my $text = substr($text, 3, 9);
    my $sum = 0;
    my @numbers = split( //, $text );
    for (my $i=0;$i<9;$i++) {
        $sum += @numbers[$i] * (10 - $i);
    }
    my $num = 11 - ($sum % 11);
    if ($num == 10) {
        $text .= 'X';
    }
    elsif ($num == 11) {
        $text .= '0';
    }
    else {
        $text .= $num;
    }
    if ($arg == 2) {
      return _format_to_isbn10($text);
    }
    else {
      return $text;
    }
}

sub zassi_to_jan {
    my ($text, $arg, $ctx) = @_;
    $arg or return $text;
    return _zassi_to_jan($text);
}

sub _zassi_to_jan {
    my ($text, $arg, $ctx) = @_;
    if ((my $len = length($text)) == 11) {
        $text = '4910' . sprintf("%07d%01d",substr($text, 0, 7),substr($text, 10, 1));
    }
    elsif ((my $len = length($text)) == 9) {
        $text = '4910' . sprintf("%07d%01d",substr($text, 0, 7),substr($text, 8, 1));
    }
    else {
        return $text;
    }
    my $sum = 0;
    my @numbers = split( //, $text );
    for(my $i=0;$i<12;$i++){
        if ($i % 2) {
            $sum += (@numbers[$i] * 3);
        } else {
            $sum += @numbers[$i];
        }
    }
    my $digit = ($sum % 10);
    if ($digit != 0) {
        $digit = 10 - $digit;
    }
    return $text . $digit;
}

sub jan_to_asin {
    my ($text, $arg, $ctx) = @_;
    $arg or return $text;
    $text =~ s/[^\d]//g;
    if ((my $len = length($text)) != 13) {
        return $text;
    }
    
    my $blog = $ctx->stash('blog');
    my $plugin = MT->component("MakeASIN");
    my $scope = "blog:".$blog->id;
    my $accesskey = $plugin->get_config_value('aws_accesskey',$scope);
    my $secretkey = $plugin->get_config_value('aws_secretkey',$scope);

    if ( $accesskey && $secretkey ) {
        require DateTime;
        my $dt = DateTime->now;
        my $config = {
            Service        => 'AWSECommerceService',
            AWSAccessKeyId => $accesskey,
            IdType         => 'EAN',
            ItemId         => $text,
            Operation      => 'ItemLookup',
            ResponseGroup  => 'ItemIds',
            SearchIndex    => 'Books',
            Timestamp      => uri_escape("$dt") . 'Z',
            Version        => '2009-03-31',
        };
        my $use_config = join '&', map { $_ . '=' . $config->{$_} } sort keys %$config;
        my $signature = "GET\necs.amazonaws.jp\n/onca/xml\n$use_config";
        use Digest::SHA qw(hmac_sha256_base64);
        my $hashed_signature = hmac_sha256_base64($signature, $secretkey);
        while (length($hashed_signature) % 4) {
            $hashed_signature .= '=';
        }
        my $response = get('http://ecs.amazonaws.jp/onca/xml?' . $use_config . '&Signature=' . URI::Escape::uri_escape($hashed_signature));
        my $response_xml = XMLin($response);

        $text = $response_xml->{Items}->{Item}->{ASIN};
    }
    return $text;
}

sub zassi_to_asin {
    my ($text, $arg, $ctx) = @_;
    $arg or return $text;
    $text = _zassi_to_jan($text);

    my $blog = $ctx->stash('blog');
    my $plugin = MT->component("MakeASIN");
    my $scope = "blog:".$blog->id;
    my $accesskey = $plugin->get_config_value('aws_accesskey',$scope);
    my $secretkey = $plugin->get_config_value('aws_secretkey',$scope);

    if ( $accesskey && $secretkey ) {
        require DateTime;
        my $dt = DateTime->now;
        my $config = {
            Service        => 'AWSECommerceService',
            AWSAccessKeyId => $accesskey,
            IdType         => 'EAN',
            ItemId         => $text,
            Operation      => 'ItemLookup',
            ResponseGroup  => 'ItemIds',
            SearchIndex    => 'Books',
            Timestamp      => uri_escape("$dt") . 'Z',
            Version        => '2009-03-31',
        };
        my $use_config = join '&', map { $_ . '=' . $config->{$_} } sort keys %$config;
        my $signature = "GET\necs.amazonaws.jp\n/onca/xml\n$use_config";
        use Digest::SHA qw(hmac_sha256_base64);
        my $hashed_signature = hmac_sha256_base64($signature, $secretkey);
        while (length($hashed_signature) % 4) {
            $hashed_signature .= '=';
        }
        my $response = get('http://ecs.amazonaws.jp/onca/xml?' . $use_config . '&Signature=' . URI::Escape::uri_escape($hashed_signature));
        my $response_xml = XMLin($response);

        $text = $response_xml->{Items}->{Item}->{ASIN};
    }
    return $text;
}

sub format_isbn13 {
    my ($text, $arg, $ctx) = @_;
    $arg or return $text;
    if ((my $len = length($text)) != 13) {
        return $text;
    }
    return _format_to_isbn13($text);
}

sub format_isbn10 {
    my ($text, $arg, $ctx) = @_;
    $arg or return $text;
    if ((my $len = length($text)) != 10) {
        return $text;
    }
    return _format_to_isbn10($text);
}

sub _format_to_isbn13 {
    my ($text, $arg, $ctx) = @_;
    return sprintf("%03d-%01d-%03d-%05d-%01d",substr($text, 0, 3),substr($text, 3, 1),substr($text, 4, 3),substr($text, 7, 5),substr($text, 12, 1));
}

sub _format_to_isbn10 {
    my ($text, $arg, $ctx) = @_;
    return sprintf("%01d-%03d-%05d-%01d",substr($text, 0, 1),substr($text, 1, 3),substr($text, 4, 5),substr($text, 9, 1));
}

sub doLog {
    my ($msg) = @_; 
    return unless defined($msg);
    require MT::Log;
    my $log = MT::Log->new;
    $log->message($msg) ;
    $log->save or die $log->errstr;
}

1