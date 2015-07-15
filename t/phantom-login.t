use Mojo::Base -strict;
use Test::More;
use Test::Mojo::Phantom;

Test::Mojo::Phantom->require_phantom;

my $t = Test::Mojo::Phantom->new('Convos');

$t->phantom_ok('/', <<'JAVASCRIPT');
var basic = function() {
  perl.ok(1, 'okidoki');
  perl.ok(1);
  perl.is(1, 1, 'one');
  perl.is(1, 1);
  perl.isnt(1, 2, 'not two');
  perl.isnt(1, 2);
};

page.evaluate(function(basic) {
  perl.elementExists('#app');
  perl.elementExistsNot('#foobar');
  perl.elementCountIs('#app', 1);
  perl.diag('title:' + document.getElementsByTagName('title')[0].textContent);
  perl.textIs('title', 'Convos');
  perl.textIsnt('title', 'Convos2kpro');
  perl.textLike('title', 'Convos');
  perl.textUnlike('title', new RegExp('foo'));
  perl.like('foo', new RegExp('oo'));
  perl.unlike('foo', new RegExp('OO'));
  perl.diag('basic inside of evaluate');
  basic();
}, basic);

perl.diag('basic outside of evaluate');
basic();
perl.ok(!page.canGoBack, 'cannot go back');
JAVASCRIPT

done_testing;
