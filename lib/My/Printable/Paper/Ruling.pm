package My::Printable::Paper::Ruling;
use warnings;
use strict;
use v5.10.0;

use lib "$ENV{HOME}/git/dse.d/printable-paper/lib";
use My::Printable::Paper::Document;
use My::Printable::Paper::Element::Rectangle;
use My::Printable::Paper::Unit qw(:const);
use My::Printable::Paper::Color qw(:const);
use My::Printable::Paper::Util qw(side_direction snapcmp :trigger);
use My::Printable::Paper::Element::Line;

use Moo;

has document => (
    is => 'rw',
    default => sub {
        return My::Printable::Paper::Document->new();
    },
    clearer => 'deleteDocument',
    handles => [
        'id',
        'filename',
        'paperSizeName',
        'width',
        'height',
        'modifiers',
        'unitType',
        'colorType',
        'print',
        'printToFile',
        'isA4SizeClass',
        'isA5SizeClass',
        'isA6SizeClass',
        'ptX',
        'ptY',
        'pt',
        'originX',
        'originY',
        'dryRun',
        'verbose',
        'generatePS',
        'generatePDF',
        'generate2Up',
        'generate4Up',
        'generate2Page',
        'generate2Page2Up',
        'generate2Page4Up',
        'disableDeveloperMark',
        'outputPaperSize',
        'output2upPaperSize',
        'output4upPaperSize',
        'unit',
        'dpi',
    ],
);

use constant rulingName => 'none';
use constant hasLineGrid => 0;
use constant hasPageNumberRectangle => 0;

use Text::Trim qw(trim);
use Data::Dumper;

sub thicknessCSS {
    my ($self) = @_;

    my $regularLineWidth = $self->regularLineWidth;
    my $majorLineWidth   = $self->majorLineWidth;
    my $feintLineWidth   = $self->feintLineWidth;
    my $regularDotWidth  = $self->regularDotWidth;
    my $majorDotWidth    = $self->majorDotWidth;
    my $feintDotWidth    = $self->feintDotWidth;
    my $marginLineWidth  = $self->marginLineWidth;

    my $regularLineOpacity = 1;
    my $majorLineOpacity   = 1;
    my $feintLineOpacity   = 1;
    my $regularDotOpacity  = 1;
    my $majorDotOpacity    = 1;
    my $feintDotOpacity    = 1;
    my $marginLineOpacity  = 1;

    if ($regularLineWidth < PD) { $regularLineOpacity = $regularLineWidth / PD; $regularLineWidth = PD; }
    if ($majorLineWidth   < PD) { $majorLineOpacity   = $majorLineWidth   / PD; $majorLineWidth   = PD; }
    if ($feintLineWidth   < PD) { $feintLineOpacity   = $feintLineWidth   / PD; $feintLineWidth   = PD; }
    if ($regularDotWidth  < PD) { $regularDotOpacity  = $regularDotWidth  / PD; $regularDotWidth  = PD; }
    if ($majorDotWidth    < PD) { $majorDotOpacity    = $majorDotWidth    / PD; $majorDotWidth    = PD; }
    if ($feintDotWidth    < PD) { $feintDotOpacity    = $feintDotWidth    / PD; $feintDotWidth    = PD; }
    if ($marginLineWidth  < PD) { $marginLineOpacity  = $marginLineWidth  / PD; $marginLineWidth  = PD; }

    return <<"EOF";
        .regular-line { stroke-width: {{ ${regularLineWidth} pt }}; opacity: ${regularLineOpacity}; }
        .major-line   { stroke-width: {{ ${majorLineWidth}   pt }}; opacity: ${majorLineOpacity};   }
        .feint-line   { stroke-width: {{ ${feintLineWidth}   pt }}; opacity: ${feintLineOpacity};   }
        .regular-dot  { stroke-width: {{ ${regularDotWidth}  pt }}; opacity: ${regularDotOpacity};  }
        .major-dot    { stroke-width: {{ ${majorDotWidth}    pt }}; opacity: ${majorDotOpacity};    }
        .feint-dot    { stroke-width: {{ ${feintDotWidth}    pt }}; opacity: ${feintDotOpacity};    }
        .margin-line  { stroke-width: {{ ${marginLineWidth}  pt }}; opacity: ${marginLineOpacity};  }
EOF
}

# when getting, if not set, return something based on colorType, and
# don't set the default.
sub aroundColor {
    my (%args) = @_;
    my $defaultName = $args{defaultName};
    my $name        = $args{name};
    return sub {
        my $orig = shift;
        my $self = shift;
        if (!scalar @_) {
            # getter
            my $result = $self->$orig() || $self->$defaultName();
            if (eval { $result->isa('My::Printable::Paper::Color') }) {
                return $result->asHex;
            }
            return $result;
        }
        # setter
        my $value = shift;
        return $self->$orig($value);
    };
}

# when setting, set the underlying value to an object
sub createColorTrigger {
    my (%args) = @_;
    my $defaultName = $args{defaultName};
    my $name        = $args{name};
    return triggerWrapper(
        sub {
            my $self = shift;
            my $value = shift;
            my $color = My::Printable::Paper::Color->new($value);
            my $hex = $color->asHex;
            $self->$name($color);
            return $hex;
        }
    );
}

sub defaultRegularLineColor {
    my ($self) = @_;
    return COLOR_BLUE if $self->colorType eq 'color';
    return COLOR_GRAY if $self->colorType eq 'grayscale';
    return COLOR_BLACK;
}

sub defaultMajorLineColor {
    my ($self) = @_;
    return COLOR_BLUE if $self->colorType eq 'color';
    return COLOR_GRAY if $self->colorType eq 'grayscale';
    return COLOR_BLACK;
}

sub defaultFeintLineColor {
    my ($self) = @_;
    return COLOR_BLUE if $self->colorType eq 'color';
    return COLOR_GRAY if $self->colorType eq 'grayscale';
    return COLOR_BLACK;
}

sub defaultMarginLineColor {
    my ($self) = @_;
    return COLOR_RED  if $self->colorType eq 'color';
    return COLOR_GRAY if $self->colorType eq 'grayscale';
    return COLOR_BLACK;
}

has regularLineColor => (is => 'rw', trigger => createColorTrigger(name => 'regularLineColor', defaultName => 'defaultRegularLineColor'));
has majorLineColor   => (is => 'rw', trigger => createColorTrigger(name => 'majorLineColor',   defaultName => 'defaultMajorLineColor'));
has feintLineColor   => (is => 'rw', trigger => createColorTrigger(name => 'feintLineColor',   defaultName => 'defaultFeintLineColor'));
has marginLineColor  => (is => 'rw', trigger => createColorTrigger(name => 'marginLineColor',  defaultName => 'defaultMarginLineColor'));

around regularLineColor => aroundColor(name => 'regularLineColor', defaultName => 'defaultRegularLineColor');
around majorLineColor   => aroundColor(name => 'majorLineColor',   defaultName => 'defaultMajorLineColor');
around feintLineColor   => aroundColor(name => 'feintLineColor',   defaultName => 'defaultFeintLineColor');
around marginLineColor  => aroundColor(name => 'marginLineColor',  defaultName => 'defaultMarginLineColor');

sub colorCSS {
    my ($self) = @_;

    my $regularLineColor = $self->regularLineColor;
    my $majorLineColor   = $self->majorLineColor;
    my $feintLineColor   = $self->feintLineColor;
    my $marginLineColor  = $self->marginLineColor;

    return <<"EOF";
        .regular-line { stroke: $regularLineColor; }
        .major-line   { stroke: $majorLineColor;   }
        .feint-line   { stroke: $feintLineColor;   }
        .regular-dot  { stroke: $regularLineColor; }
        .major-dot    { stroke: $majorLineColor;   }
        .feint-dot    { stroke: $feintLineColor;   }
        .margin-line  { stroke: $marginLineColor;  }
EOF
}

sub additionalCSS {
    my ($self) = @_;
    return undef;
}

sub generate {
    my ($self) = @_;

    my $unit = $self->getUnit();
    $self->document->setUnit($unit) if defined $unit;

    my $originX = $self->getOriginX();
    $self->document->originX($originX) if defined $originX;

    my $originY = $self->getOriginY();
    $self->document->originY($originY) if defined $originY;

    $self->generateRuling();

    if ($self->hasPageNumberRectangle) {
        $self->document->appendElement(
            $self->generatePageNumberRectangle()
        );
    }

    if ($self->hasMarginLine('left')) {
        $self->document->appendElement($self->generateMarginLine('left'));
    }
    if ($self->hasMarginLine('right')) {
        $self->document->appendElement($self->generateMarginLine('right'));
    }
    if ($self->hasMarginLine('top')) {
        $self->document->appendElement($self->generateMarginLine('top'));
    }
    if ($self->hasMarginLine('bottom')) {
        $self->document->appendElement($self->generateMarginLine('bottom'));
    }

    my $css = '';
    $css .= $self->thicknessCSS;
    $css .= $self->colorCSS;
    if (defined $self->additionalCSS) {
        $css .= $self->additionalCSS;
    }
    $self->document->additionalStyles($css);

    $self->document->generate();
}

# *around* which to define subclass methods
sub generateRuling {
    my ($self) = @_;
}

sub generatePageNumberRectangle {
    my ($self) = @_;
    my $cssClass = sprintf('%s rectangle', $self->getRegularLineCSSClass());
    my $rect = My::Printable::Paper::Element::Rectangle->new(
        document => $self->document,
        id => 'page-number-rect',
        cssClass => $cssClass,
    );
    my $from_side = $self->modifiers->has('even-page') ? 'left' : 'right';
    my $x_side    = $self->modifiers->has('even-page') ? 'x1'   : 'x2';
    if ($self->unitType eq 'imperial') {
        $rect->$x_side(sprintf('1/4in from %s', $from_side));
        $rect->y2('1/4in from bottom');
        $rect->width('1in');
        $rect->height('3/8in');
    } else {
        $rect->$x_side(sprintf('1/4in from %s', $from_side));
        $rect->y2('6mm from bottom');
        $rect->width('30mm');
        $rect->height('9mm');
    }
    return $rect;
}

sub getUnit {
    my ($self) = @_;

    if ($self->modifiers->has('unit')) {
        my $unit = $self->modifiers->get('unit');
        if (defined $unit) {
            return $unit;
        }
    }

    my $hasDenserGrid = grep { $self->modifiers->has($_) }
        qw(5-per-inch denser-grid 1/5in 5mm);

    if ($self->unitType eq 'imperial') {
        if ($hasDenserGrid) {
            return '1/5in';
        } else {
            return '1/4in';
        }
    } else {
        if ($hasDenserGrid) {
            return '5mm';
        } else {
            return '6mm';
        }
    }
}

###############################################################################

sub getMarginLineCSSClass {
    my ($self) = @_;
    return 'margin-line';
}

sub getRegularDotCSSClass {
    my ($self) = @_;
    return 'regular-dot';
}

sub getMajorDotCSSClass {
    my ($self) = @_;
    return 'major-dot';
}

sub getFeintDotCSSClass {
    my ($self) = @_;
    return 'feint-dot';
}

sub getRegularLineCSSClass {
    my ($self) = @_;
    return 'regular-line';
}

sub getFeintLineCSSClass {
    my ($self) = @_;
    return 'feint-line';
}

sub getMajorLineCSSClass {
    my ($self) = @_;
    return 'major-line';
}

###############################################################################

has rawRegularLineWidth => (is => 'rw');
has rawMajorLineWidth   => (is => 'rw');
has rawFeintLineWidth   => (is => 'rw');
has rawRegularDotWidth  => (is => 'rw');
has rawMajorDotWidth    => (is => 'rw');
has rawFeintDotWidth    => (is => 'rw');
has rawMarginLineWidth  => (is => 'rw');

sub regularLineWidth {
    my $self = shift;
    if (!scalar @_) {
        if (!defined $self->rawRegularLineWidth) {
            return $self->computeRegularLineWidth();
        }
        return $self->rawRegularLineWidth;
    }
    my $value = shift;
    $value = $self->unit->pt($value);
    return $self->rawRegularLineWidth($value);
}

sub majorLineWidth {
    my $self = shift;
    if (!scalar @_) {
        if (!$self->rawMajorLineWidth) {
            return $self->computeMajorLineWidth();
        }
        return $self->rawMajorLineWidth;
    }
    my $value = shift;
    $value = $self->unit->pt($value);
    return $self->rawMajorLineWidth($value);
}

sub feintLineWidth {
    my $self = shift;
    if (!scalar @_) {
        if (!$self->rawFeintLineWidth) {
            return $self->computeFeintLineWidth();
        }
        return $self->rawFeintLineWidth;
    }
    my $value = shift;
    $value = $self->unit->pt($value);
    return $self->rawFeintLineWidth($value);
}

sub regularDotWidth {
    my $self = shift;
    if (!scalar @_) {
        if (!$self->rawRegularDotWidth) {
            return $self->computeRegularDotWidth();
        }
        return $self->rawRegularDotWidth;
    }
    my $value = shift;
    $value = $self->unit->pt($value);
    return $self->rawRegularDotWidth($value);
}

sub majorDotWidth {
    my $self = shift;
    if (!scalar @_) {
        if (!$self->rawMajorDotWidth) {
            return $self->computeMajorDotWidth();
        }
        return $self->rawMajorDotWidth;
    }
    my $value = shift;
    $value = $self->unit->pt($value);
    return $self->rawMajorDotWidth($value);
}

sub feintDotWidth {
    my $self = shift;
    if (!scalar @_) {
        if (!$self->rawFeintDotWidth) {
            return $self->computeFeintDotWidth();
        }
        return $self->rawFeintDotWidth;
    }
    my $value = shift;
    $value = $self->unit->pt($value);
    return $self->rawFeintDotWidth($value);
}

sub marginLineWidth {
    my $self = shift;
    if (!scalar @_) {
        if (!$self->rawMarginLineWidth) {
            return $self->computeMarginLineWidth();
        }
        return $self->rawMarginLineWidth;
    }
    my $value = shift;
    $value = $self->unit->pt($value);
    return $self->rawMarginLineWidth($value);
}

# before thinner-lines, thinner-dots, thinner-grid, denser-grid, and
# other modifiers are applied.

sub baseRegularLineWidth {
    my ($self) = @_;
    return 2 * PD if $self->colorType eq 'black';
    return 8 * PD;
}

sub baseMajorLineWidth {
    my ($self) = @_;
    return  4 / sqrt(2) * PD if $self->colorType eq 'black';
    return 16 / sqrt(2) * PD;
}

sub baseFeintLineWidth {
    my ($self) = @_;
    return 2 / sqrt(2) * PD if $self->colorType eq 'black';
    return 8 / sqrt(2) * PD;
}

sub baseRegularDotWidth {
    my ($self) = @_;
    return 8 * PD if $self->colorType eq 'black';
    return 16 * PD;
}

sub baseMajorDotWidth {
    my ($self) = @_;
    return 16 * PD if $self->colorType eq 'black';
    return 32 * PD;
}

sub baseFeintDotWidth {
    my ($self) = @_;
    return 4 * PD if $self->colorType eq 'black';
    return 8 * PD;
}

sub baseMarginLineWidth {
    my ($self) = @_;
    return 2 * PD if $self->colorType eq 'black';
    return 8 * PD;
}

sub computeRegularLineWidth {
    my ($self) = @_;
    my $x = $self->baseRegularLineWidth;
    if ($self->modifiers->has('xx-thinner-lines')) {
        $x /= (2 * sqrt(2));
    } elsif ($self->modifiers->has('x-thinner-lines')) {
        $x /= 2;
    } elsif ($self->modifiers->has('thinner-lines')) {
        $x /= sqrt(2);
    }
    if ($x < PD) {
        $x = PD;
    }
    return $x;
}

sub computeMajorLineWidth {
    my ($self) = @_;
    my $x = $self->baseMajorLineWidth;
    if ($self->modifiers->has('xx-thinner-lines')) {
        $x /= (2 * sqrt(2));
    } elsif ($self->modifiers->has('x-thinner-lines')) {
        $x /= 2;
    } elsif ($self->modifiers->has('thinner-lines')) {
        $x /= sqrt(2);
    }
    if ($self->modifiers->has('xx-thicker-major-lines')) {
        $x *= (2 * sqrt(2));
    } elsif ($self->modifiers->has('x-thicker-major-lines')) {
        $x *= 2;
    } elsif ($self->modifiers->has('thicker-major-lines')) {
        $x *= sqrt(2);
    }
    if ($self->modifiers->has('denser-grid')) {
        $x /= sqrt(2);
    }
    if ($x < PD) {
        $x = PD;
    }
    return $x;
}

sub computeFeintLineWidth {
    my ($self) = @_;
    my $x = $self->baseFeintLineWidth;
    if ($self->modifiers->has('xx-thinner-lines')) {
        $x /= (2 * sqrt(2));
    } elsif ($self->modifiers->has('x-thinner-lines')) {
        $x /= 2;
    } elsif ($self->modifiers->has('thinner-lines')) {
        $x /= sqrt(2);
    }
    if ($self->modifiers->has('xx-thinner-grid')) {
        $x /= (2 * sqrt(2));
    } elsif ($self->modifiers->has('x-thinner-grid')) {
        $x /= 2;
    } elsif ($self->modifiers->has('thinner-grid')) {
        $x /= sqrt(2);
    }
    if ($self->modifiers->has('denser-grid')) {
        $x /= sqrt(2);
    }
    if ($x < PD) {
        $x = PD;
    }
    return $x;
}

sub computeRegularDotWidth {
    my ($self) = @_;
    my $x = $self->baseRegularDotWidth;
    if ($self->modifiers->has('xx-thinner-dots')) {
        $x /= (2 * sqrt(2));
    } elsif ($self->modifiers->has('x-thinner-dots')) {
        $x /= 2;
    } elsif ($self->modifiers->has('thinner-dots')) {
        $x /= sqrt(2);
    }
    if ($x < PD) {
        $x = PD;
    }
    return $x;
}

sub computeMajorDotWidth {
    my ($self) = @_;
    my $x = $self->baseMajorDotWidth;
    if ($self->modifiers->has('xx-thinner-dots')) {
        $x /= (2 * sqrt(2));
    } elsif ($self->modifiers->has('x-thinner-dots')) {
        $x /= 2;
    } elsif ($self->modifiers->has('thinner-dots')) {
        $x /= sqrt(2);
    }
    if ($x < PD) {
        $x = PD;
    }
    return $x;
}

sub computeFeintDotWidth {
    my ($self) = @_;
    my $x = $self->baseFeintDotWidth;
    if ($self->modifiers->has('xx-thinner-dots')) {
        $x /= (2 * sqrt(2));
    } elsif ($self->modifiers->has('x-thinner-dots')) {
        $x /= 2;
    } elsif ($self->modifiers->has('thinner-dots')) {
        $x /= sqrt(2);
    }
    if ($x < PD) {
        $x = PD;
    }
    return $x;
}

sub computeMarginLineWidth {
    my ($self) = @_;
    my $x = $self->baseMarginLineWidth;
    if ($x < PD) {
        $x = PD;
    }
    return $x;
}

###############################################################################

# 'quadrille'     => 'My::Printable::Paper::Ruling::Quadrille'
# 'line-dot-grid' => 'My::Printable::Paper::Ruling::LineDotGrid'
sub getRulingClassName {
    my ($self, $name) = @_;
    my $class_suffix = $name;
    $class_suffix =~ s{(^|[-_]+)
                       ([[:alpha:]])}
                      {uc $2}gex;
    my $ruling_class_name = "My::Printable::Paper::Ruling::" . $class_suffix;
    return $ruling_class_name;
}

sub getOriginX {
    my ($self, $side) = @_;
    $side //= 'left';
    my $value;
    if ($self->modifiers->has('left-margin-line') || $self->modifiers->has('margin-line')) {
        $value = $self->modifiers->get('left-margin-line') // $self->modifiers->get('margin-line');
    } elsif ($self->modifiers->has('right-margin-line')) {
        $value = $self->modifiers->get('right-margin-line');
    }
    if (defined $value && $value eq 'yes') {
        $value = $self->getDefaultMarginLineX($side);
    }
    return $value;
}

sub getOriginY {
    my ($self, $side) = @_;
    $side //= 'top';
    my $value;
    if ($self->modifiers->has('top-margin-line')) {
        $value = $self->modifiers->get('top-margin-line');
    } elsif ($self->modifiers->has('bottom-margin-line')) {
        $value = $self->modifiers->get('bottom-margin-line');
    }
    if (defined $value && $value eq 'yes') {
        $value = $self->getDefaultMarginLineY($side);
    }
    return $value;
}

sub getDefaultMarginLineY {
    my ($self, $side) = @_;
    $side //= 'top';
    if ($self->unitType eq 'imperial') {
        return '0.5in from ' . $side;
    } else {
        return '12mm from ' . $side;
    }
}

sub getDefaultMarginLineX {
    my ($self, $side) = @_;
    $side //= 'left';
    if ($self->unitType eq 'imperial') {
        if ($self->isA6SizeClass()) {
            return '0.5in from ' . $side;
        } elsif ($self->isA5SizeClass()) {
            return '0.75in from ' . $side;
        } else {
            return '1.25in from ' . $side;
        }
    } else {
        if ($self->isA6SizeClass()) {
            return '12mm from ' . $side;
        } elsif ($self->isA5SizeClass()) {
            return '18mm from ' . $side;
        } else {
            return '32mm from ' . $side;
        }
    }
}

###############################################################################

sub hasMarginLine {
    my ($self, $side) = @_;
    $side //= 'left';
    my $direction = side_direction($side);
    if (!defined $direction) {
        die("margin line side must be left, right, top, or bottom\n");
    }

    my $method2;
    my $result;
    if ($side eq 'left') {
        $method2 = 'hasLeftMarginLine';
        $result = $self->modifiers->has('left-margin-line') || $self->modifiers->has('margin-line');
    }
    if ($side eq 'right') {
        $method2 = 'hasRightMarginLine';
        $result = $self->modifiers->has('right-margin-line');
    }
    if ($side eq 'top') {
        $method2 = 'hasTopMarginLine';
        $result = $self->modifiers->has('top-margin-line');
    }
    if ($side eq 'bottom') {
        $method2 = 'hasBottomMarginLine';
        $result = $self->modifiers->has('bottom-margin-line');
    }
    $result ||= ($self->can($method2) && $self->$method2());
    return $result;
}

sub getMarginLinePosition {
    my ($self, $side) = @_;
    $side //= 'left';
    my $direction = side_direction($side);
    if (!defined $direction) {
        die("margin line side must be left, right, top, or bottom\n");
    }

    my $marginLinePosition;
    if ($direction eq 'vertical') {
        if ($side eq 'left') {
            $marginLinePosition = $self->modifiers->get('left-margin-line') // $self->modifiers->get('margin-line');
        } else {
            $marginLinePosition = $self->modifiers->get('right-margin-line');
        }
        if (!defined $marginLinePosition || $marginLinePosition eq 'yes') {
            my $originX = $self->ptX($self->getOriginX($side));
            if (!defined $originX) {
                return undef;
            }
            my $halfX = $self->ptX('50%');
            my $originXIsLeftOrCenter = snapcmp($originX, $halfX) <= 0;
            my $isOppositeSide = 0;
            if ($side eq 'left') {
                if ($originXIsLeftOrCenter) {
                    $marginLinePosition = $originX;
                } else {
                    $marginLinePosition = $self->width - $originX;
                    $isOppositeSide = 1;
                }
            } else {
                if ($originXIsLeftOrCenter) {
                    $marginLinePosition = $self->width - $originX;
                } else {
                    $marginLinePosition = $originX;
                    $isOppositeSide = 1;
                }
            }
            if ($isOppositeSide) {
                # eh?
            }
        }
    } else {
        if ($side eq 'top') {
            $marginLinePosition = $self->modifiers->get('top-margin-line');
        } else {
            $marginLinePosition = $self->modifiers->get('bottom-margin-line');
        }
        if (!defined $marginLinePosition || $marginLinePosition eq 'yes') {
            my $originY = $self->ptY($self->getOriginY($side));
            if (!defined $originY) {
                return undef;
            }
            my $halfY = $self->ptY('50%');
            my $originYIsTopOrCenter = snapcmp($originY, $halfY) <= 0;
            my $isOppositeSide = 0;
            if ($side eq 'top') {
                if ($originYIsTopOrCenter) {
                    $marginLinePosition = $originY;
                } else {
                    $marginLinePosition = $self->height - $originY;
                    $isOppositeSide = 1;
                }
            } else {
                if ($originYIsTopOrCenter) {
                    $marginLinePosition = $self->height - $originY;
                    $isOppositeSide = 1;
                } else {
                    $marginLinePosition = $originY;
                }
            }
            if ($isOppositeSide) {
                # eh?
            }
        }
    }
    return $marginLinePosition;
}

sub generateMarginLine {
    my ($self, $side) = @_;
    $side //= 'left';
    my $direction = side_direction($side);
    if (!defined $direction) {
        die("margin line side must be left, right, top, or bottom\n");
    }
    if (!$self->hasMarginLine($side)) {
        return;
    }

    my $cssClass = trim(($self->getMarginLineCSSClass // '') . ' ' . $direction);
    my $margin_line = My::Printable::Paper::Element::Line->new(
        document => $self->document,
        id => 'margin-line',
        cssClass => $cssClass,
    );
    if ($direction eq 'vertical') {
        my $x = $self->getMarginLinePosition($side);
        if (!defined $x) {
            return undef;
        }
        $margin_line->setX($x);
        return $margin_line;
    } else {                    # horizontal
        my $y = $self->getMarginLinePosition($side);
        if (!defined $y) {
            return undef;
        }
        $margin_line->setY($y);
        return $margin_line;
    }
}

###############################################################################

1;
