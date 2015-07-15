package Test::Mojo::Phantom;

=head1 NAME

Test::Mojo::Phantom - Test your dynamic web pages

=head1 DESCRIPTION

L<Test::Mojo::Phantom> is a module which use L<Mojo::Phantom> to run
tests.

This method adds a "perl" object to the rendered webpage which again can be
used to run tests in the web page and communicate the results back to
"perl space". This is done by emitting a
L<onConsoleMessage|http://phantomjs.org/api/webpage/handler/on-console-message.html>
event with a message in TAP format. Examples:

  ok 1 - description
  not ok 2 - other description

=head1 SYNOPSIS

  use Test::Mojo::Phantom;

  # skip this test unless Mojo::Phantom is available
  Test::Mojo::Phantom->require_phantom;

  my $t = Test::Mojo::Phantom->new("MyApp");

  $t->phantom_ok("/", <<'JAVASCRIPT');
  page.evaluate(function() {
    perl.elementExists("#app");
  });

  perl.ok(!page.canGoBack, "cannot go back");
  JAVASCRIPT

=head1 JAVASCRIPT METHODS

The JavaScript methods listed below are available from the "perl" object.

=head2 diag

Same as L<Test::More::diag>.
Available from inside and outside of C<evaluate()>.

=head2 elementCountIs

Same as L<Test::Mojo/element_count_is>
Available from inside of C<evaluate()>.

=head2 elementExists

Same as L<Test::Mojo/element_exists>
Available from inside of C<evaluate()>.

=head2 elementExistsNot

Same as L<Test::Mojo/element_exists_not>
Available from inside of C<evaluate()>.

=head2 textIs

Same as L<Test::Mojo/text_is>
Available from inside of C<evaluate()>.

=head2 textIsnt

Same as L<Test::Mojo/text_isnt>
Available from inside of C<evaluate()>.

=head2 textLike

Same as L<Test::Mojo/text_like>
Available from inside of C<evaluate()>.

=head2 textUnlike

Same as L<Test::Mojo/text_unlike>
Available from inside of C<evaluate()>.

=head2 is

Same as L<Test::More/is>
Available from inside and outside of C<evaluate()>.

=head2 isnt

Same as L<Test::More/isnt>
Available from inside and outside of C<evaluate()>.

=head2 like

Same as L<Test::More/like>
Available from inside of C<evaluate()>.

=head2 ok

Same as L<Test::More/ok>
Available from inside and outside of C<evaluate()>.

=head2 unlike

Same as L<Test::More/unlike>
Available from inside of C<evaluate()>.

=cut

use Mojo::Base 'Test::Mojo';
use Test::More ();

=head1 ATTRIBUTES

This class inherit from L<Test::Mojo> and implements the following attributes.

=head2 viewport_size

  $array_ref = $self->viewport_size;
  $self = $self->viewport_size([1280, 800]);

=cut

has viewport_size => sub { [1280, 800] };

=head1 METHODS

This class inherit from L<Test::Mojo> and implements the following methods.

=head2 require_phantom

Will L<skip all|Test::More/plan> tests unless L<Mojo::Phantom> is available.

=cut

sub require_phantom {
  Test::More::plan(skip_all => $@) unless eval 'require Mojo::Phantom;1';
}

=head2 phantom_ok

See L<Test::Mojo::Role::Phantom/phantom_ok>.

=cut

sub phantom_ok {
  my $self = shift;
  my $opts = ref $_[-1] ? pop : {};
  my $js   = pop;
  my $base = $self->ua->server->nb_url;
  my $url  = $self->app->url_for(@_);

  unless ($url->is_abs) {
    $url = $url->to_abs($base);
  }

  $self->modify_app({}) unless $self->{modified}++;

  my $phantom = $opts->{phantom} || do {
    my %bind = (
      diag => 'Test::More::diag',
      fail => 'Test::More::fail',
      isnt => 'Test::More::isnt',
      is   => 'Test::More::is',
      ok   => 'Test::More::ok',
      %{$opts->{bind} || {}},
    );

    Mojo::Phantom->new(
      base    => $base,
      bind    => \%bind,
      cookies => $self->ua->cookie_jar->all,
      setup   => $self->_setup_code($opts),
      package => $opts->{package} || caller,
    );
  };

  my $name = $opts->{name} || 'all phantom tests successful';
  my $block = sub {
    Test::More::plan(tests => $opts->{plan}) if $opts->{plan};
    Mojo::IOLoop->delay(
      sub { $phantom->execute_url($url, $js, shift->begin) },
      sub {
        my ($delay, $err, $status) = @_;
        if ($status) {
          my $exit = $status >> 8;
          my $sig  = $status & 127;
          my $msg  = $exit ? "status: $exit" : "signal: $sig";
          Test::More::diag("phantom exitted with $msg");
        }
        die $err if $err;
      },
    )->catch(sub { Test::More::fail($_[1]) })->wait;
  };
  local $Test::Builder::Level = $Test::Builder::Level + 1;
  return $self->success(Test::More::subtest($name => $block));
}

=head2 modify_app

This method will add an "after_render" hook which will add two JavaScripts to
the HTML page. The JavaScripts are added directly after "<head>" using a regexp.

=cut

sub modify_app {
  my ($self, $args) = @_;

  $args->{js} ||= join '', map {qq(<script src="$_"></script>)} qw( /js/phantom/bind-polyfill.js /js/phantom/test.js );

  push @{$self->app->static->classes}, __PACKAGE__;
  $self->app->hook(
    after_render => sub {
      my ($c, $output, $format) = @_;
      $$output =~ s!<head>!<head>$args->{js}! if $format =~ /html/;
    }
  );

  return $self;
}

sub _setup_code {
  my ($self,  $opts)   = @_;
  my ($width, $height) = @{$self->viewport_size};
  my $setup = $opts->{setup} || '';

  return <<"  JAVASCRIPT";
page.viewportSize = {width: $width, height: $height};
page.onConsoleMessage = function(msg) {
  var tap = msg.match(/^(ok|not ok)\\s(\\d+)\\s*(.*)/);
  return tap ? perl.ok(tap[1] == 'ok' ? 1 : 0, tap[3].replace(/^\\W+/, '')) : perl.diag(msg);
};
$setup
  JAVASCRIPT
}

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014, Jan Henning Thorsen

This program is free software, you can redistribute it and/or modify it under
the terms of the Artistic License version 2.0.

=head1 AUTHOR

Jan Henning Thorsen - C<jhthorsen@cpan.org>

=cut

1;
__DATA__
@@ js/phantom/bind-polyfill.js
if (typeof Function.prototype.bind != 'function') {
  Function.prototype.bind = function bind(obj) {
    var args = Array.prototype.slice.call(arguments, 1),
      self = this,
      nop = function() {
      },
      bound = function() {
        return self.apply(
          this instanceof nop ? this : (obj || {}), args.concat(
            Array.prototype.slice.call(arguments)
          )
        );
      };
    nop.prototype = this.prototype || {};
    bound.prototype = new nop();
    return bound;
  };
}
@@ js/phantom/test.js
;(function(module) {
  var Perl = function() {
    this.context = document;
    this.n = 1;
    this.report = function(msg) { console.log(msg); };
  };

  if (module.exports) {
    module.exports = Perl;
  }
  else {
    window.perl = new Perl();
  }

  var proto = Perl.prototype;

  proto.diag = function(msg) {
    this.report(msg);
    return this;
  };

  proto.elementCountIs = function(selector, count, desc) {
    if (!desc) desc = 'element count for selector "' + selector + '" is ' + count;
    return this.is(this.context.querySelectorAll(selector).length, count, desc);
  };

  proto.elementExists = function(selector, desc) {
    if (!desc) desc = 'element for selector "' + selector + '" exists';
    return this.ok(this.context.querySelector(selector), desc);
  };

  proto.elementExistsNot = function(selector, desc) {
    if (!desc) desc = 'no element for selector "' + selector + '"';
    return this.ok(!this.context.querySelector(selector), desc);
  };

  proto.textIs = function(selector, value, desc) {
    var e = this.context.querySelector(selector);
    if (!desc) desc = 'exact match for selector "' + selector + '"';
    return this.is(e ? e.textContent : undefined, value, desc);
  };

  proto.textIsnt = function(selector, value, desc) {
    var e = this.context.querySelector(selector);
    if (!desc) desc = 'no match for selector "' + selector + '"';
    return this.isnt(e ? e.textContent : undefined, value, desc);
  };

  proto.textLike = function(selector, re, desc) {
    var e = this.context.querySelector(selector);
    if (!desc) desc = 'similar match for selector "' + selector + '"';
    return this.like(e ? e.textContent : undefined, re, desc);
  };

  proto.textUnlike = function(selector, re, desc) {
    var e = this.context.querySelector(selector);
    if (!desc) desc = 'similar match for selector "' + selector + '"';
    return this.unlike(e ? e.textContent : undefined, re, desc);
  };

  proto.is = function(a, b, desc) {
    if (!desc) desc = 'is the same';
    return this.ok(a == b, desc);
  };

  proto.isnt = function(a, b, desc) {
    if (!desc) desc = 'not the same';
    return this.ok(a != b, desc);
  };

  proto.like = function(s, re, desc) {
    if (!desc) desc = 'match for regexp';
    if (!re.exec) re = new RegExp(re);
    return this.ok(typeof s == 'string' ? re.exec(s) : false, desc);
  };

  proto.ok = function(bool, desc) {
    this.n++;
    this.report((bool ? 'ok' : 'not ok') + ' ' + this.n + ' - ' + (desc || ''));
    return bool;
  };

  proto.unlike = function(s, re, desc) {
    if (!desc) desc = 'no match for regexp';
    if (!re.exec) re = new RegExp(re);
    return this.ok(typeof s == 'string' ? !re.exec(s) : false, desc);
  };
})(window || module);
