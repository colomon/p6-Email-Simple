class Email::Simple::Header;

has $!crlf;
has @!headers;

grammar Headers {
    regex TOP {
	<entry>+
    }
    regex entry {
	<name>\: \s* <value> <newline>
    }
    token name {
	<-[: ]>*
    }
    regex value {
	\N*
	(<newline> \s+ \N*)?
    }
    token newline {
	\n | \r | \r\n | \n\r
    }
}

multi method new (Array @headers, Str :$crlf = "\r\n") {
    if @headers[0] ~~ Array {
	self.bless(*, crlf => $crlf, headers => @headers);
    } else {
	my @folded-headers;
	loop (my $x=0;$x < +@headers;$x+=2) {
	    @folded-headers.push([@headers[$x], @headers[$x+1]]);
	}
	
	self.bless(*, crlf => $crlf, headers => @folded-headers);
    }
}

multi method new (Str $header-text, Str :$crlf = "\r\n") {
    my $parsed = Headers.parse($header-text);
    my @entries = $parsed<entry>.list;
    my @headers;
    for @entries {
	my $name = $_<name>;
	my $value = $_<value>;
	$value = $value.Str;
	$value ~~ s:g/\s* $crlf \s*/ /;
	push(@headers, [~$name, $value]);
    }

    self.bless(*, crlf => $crlf, headers => @headers);
}

submethod BUILD (:$!crlf, :@!headers) { }

method as-string {
    my $header-str;
    
    for @!headers {
	my $header = $_[0] ~ ': ' ~ $_[1];
	$header-str ~= self!fold($header);
    }

    return $header-str;
}
method Str { self.as-string }

class HeaderResponse is Positional {
    has @.values;

    method new(@values) {
        self.bless(*, :@values);
    }

    method get_at($k) { @.values.get_at($k) }
    method list() { @.values.list }

    method Str { @.values[0] }
}

method header-names {
    my @names = gather {
	for @!headers {
	    take $_[0];
	}
    }

    return @names;
}

method header-pairs {
    return @!headers;
}

method header (Str $name) {
    my @values = gather {
	for @!headers {
	    if lc($_[0]) eq lc($name) {
		take $_[1];
	    }
	}
    }

    return HeaderResponse.new(@values);
}

method header-set ($field, *@values) {
    my @indices;
    my $x = 0;
    for @!headers {
	if lc($_[0]) eq lc($field) {
	    push(@indices, $x);
	}
	$x++;
    }

    if +@indices > +@values {
	my $overage = +@indices - +@values;
	for 1..$overage {
	    @!headers.splice(@indices[*-1],1);
	    @indices.pop();
	}
    } elsif +@values > +@indices {
	my $underage = +@values - +@indices;
	for 1..$underage {
	    @!headers.push([$field, '']);
	    @indices.push(+@!headers-1);
	}
    }

    for 0..(+@indices - 1) {
	@!headers[@indices[$_]] = [$field, @values[$_]];
    }

    return HeaderResponse.new(@values);
}

method crlf {
    return $!crlf;
}

method !fold (Str $line) {
    my $limit = self!default-fold-at - 1;
    
    if $line.chars <= $limit {
	return $line ~ self.crlf;
    }

    my $folded;
    while $line.chars {
	if $line ~~ s/^(.{0,$limit})\s// {
	    $folded ~= $1 ~ self.crlf;
	    if $line.chars {
		$folded ~= self!default-fold-indent;
	    }
	} else {
	    $folded ~= $line ~ self.crlf;
	    $line = '';
	}
    }

    return $folded;
}
method !default-fold-at { 78 }
method !default-fold-indent { " " }
