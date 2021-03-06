package My::Printable::Paper::Ruling::Anode;
# Based on Doane Paper
use warnings;
use strict;
use v5.10.0;

use lib "$ENV{HOME}/git/dse.d/printable-paper/lib";

use Moo;

extends 'My::Printable::Paper::Ruling';

use My::Printable::Paper::Element::Grid;
use My::Printable::Paper::Element::Lines;
use My::Printable::Paper::Element::Line;
use My::Printable::Paper::Unit qw(:const);

use constant rulingName => 'anode';
use constant hasLineGrid => 1;
use constant hasLeftMarginLine => 1;

sub baseFeintLineWidth {
    my ($self) = @_;
    return 1 * PD if $self->colorType eq 'black';
    return 4 / sqrt(2) * PD;
}

around generateRuling => sub {
    my ($orig, $self) = @_;

    my $grid = My::Printable::Paper::Element::Grid->new(
        document => $self->document,
        id => 'grid',
        cssClass => $self->getFeintLineCSSClass,
    );
    $grid->setSpacing('1/3unit');

    if ($self->modifiers->has('denser-grid')) {
        $grid->originY('50%');
        $grid->originY($grid->originY + $grid->ptY('1/3unit'));
    }

    my $lines = My::Printable::Paper::Element::Lines->new(
        document => $self->document,
        id => 'lines',
        cssClass => $self->getRegularLineCSSClass,
    );
    $lines->setSpacing('1unit');

    if ($self->modifiers->has('denser-grid')) {
        $lines->originY('50%');
        $lines->originY($lines->originY + $lines->ptY('1/3unit'));
    }

    $self->document->appendElement($grid);
    $self->document->appendElement($lines);

    $self->$orig();
};

around getUnit => sub {
    my ($orig, $self) = @_;
    if ($self->unitType eq 'imperial') {
        if ($self->modifiers->has('denser-grid')) {
            return '1/4in';
        } else {
            return '3/8in';
        }
    } else {
        if ($self->modifiers->has('denser-grid')) {
            return '6mm';
        } else {
            return '9mm';
        }
    }
};

sub getOriginX {
    my ($self) = @_;
    if ($self->unitType eq 'imperial') {
        return '7/8in';
    } else {
        return '22mm';
    }
}

1;
