package My::Printable::Paper::2::Paper;

use warnings;
use strict;
use v5.10.0;

use lib "$ENV{HOME}/git/dse.d/printable-paper/lib";
use My::Printable::Paper::2::PaperSize;
use My::Printable::Paper::2::LineType;
use My::Printable::Paper::2::PointSeries;
use My::Printable::Paper::2::Coordinate;
use My::Printable::Paper::2::Util qw(:stroke);
use My::Printable::Paper::2::Converter;

use Moo;

has id           => (is => 'rw');
has basename     => (is => 'rw');
has originX      => (is => 'rw', default => '50%');
has originY      => (is => 'rw', default => '50%');
has gridSpacingX => (is => 'rw', default => '1/4in');
has gridSpacingY => (is => 'rw', default => '1/4in');
has clipLeft     => (is => 'rw', default => 0);
has clipRight    => (is => 'rw', default => 0);
has clipTop      => (is => 'rw', default => 0);
has clipBottom   => (is => 'rw', default => 0);
has size => (
    is => 'rw',
    default => sub {
        my $self = shift;
        return My::Printable::Paper::2::PaperSize->new(paper => $self);
    },
    handles => [
        'width',
        'height',
        'orientation',
    ],
    trigger => sub {
        state $recurse = 0;
        return if $recurse;
        $recurse += 1;
        my $self = shift;
        sub {
            my $value = $self->size;
            if (eval { $value->isa('My::Printable::Paper::2::PaperSize') }) {
                # do nothing
            } else {
                $self->size(My::Printable::Paper::2::PaperSize->new(
                    $value, paper => $self
                ));
            }
        }->();
        $recurse -= 1;
    },
);
has lineTypeHash    => (is => 'rw', default => sub { return {}; });
has pointSeriesHash => (is => 'rw', default => sub { return {}; });
has dpi             => (is => 'rw', default => 600);

has converter => (
    is => 'rw', lazy => 1, default => sub {
        my $self = shift;
        return My::Printable::Paper::2::Converter->new(paper => $self);
    },
);

has svgDocument => (
    is => 'rw', lazy => 1, default => sub {
        my $self = shift;
        my $doc = XML::LibXML::Document->new('1.0', 'UTF-8');
        return $doc;
    },
);

has svgRootElement => (
    is => 'rw', lazy => 1, default => sub {
        my $self = shift;
        my $root = $self->svgDocument->createElement('svg');
        my $width  = $self->xx('width');
        my $height = $self->yy('height');
        my $viewBox = sprintf('%.3f %.3f %.3f %.3f', 0, 0, $width, $height);
        $root->setAttribute('width',  sprintf('%.3fpt', $width));
        $root->setAttribute('height', sprintf('%.3fpt', $height));
        $root->setAttribute('viewBox', $viewBox);
        $root->setAttribute('xmlns', 'http://www.w3.org/2000/svg');
        $self->svgDocument->setDocumentElement($root);
        return $root;
    },
);

has svgDefsElement => (
    is => 'rw', lazy => 1, default => sub {
        my $self = shift;
        my $defs = $self->svgDocument->createElement('defs');
        $self->svgRootElement->appendChild($defs);
        return $defs;
    },
);

has svgStyleElement => (
    is => 'rw', lazy => 1, default => sub {
        my $self = shift;
        my $style = $self->svgDocument->createElement('style');
        $self->svgRootElement->appendChild($style);
        return $style;
    },
);

has svgTopLevelGroupElement => (
    is => 'rw', lazy => 1, default => sub {
        my $self = shift;
        my $g = $self->svgDocument->createElement('g');
        $g->setAttribute('id', 'top-level-group');
        $self->svgRootElement->appendChild($g);
        return $g;
    },
);

has clipPathElement => (is => 'rw');

use List::Util qw(max);

sub updateClipPathElement {
    my $self = shift;
    if ($self->clipPathElement) {
        $self->svgDefsElement->removeChild($self->clipPathElement);
        $self->clipPathElement(undef);
    }
    my $width  = $self->xx($self->width);
    my $height = $self->xx($self->height);
    my $clipLeft   = max($self->xx($self->clipLeft), 0);
    my $clipRight  = max($self->xx($self->clipRight), 0);
    my $clipTop    = max($self->yy($self->clipTop), 0);
    my $clipBottom = max($self->yy($self->clipBottom), 0);

    if ($clipLeft > 0 || $clipRight > 0 || $clipTop > 0 || $clipBottom > 0) {
        my $clipX = $clipLeft;
        my $clipY = $clipTop;
        my $clipWidth  = $width  - $clipLeft - $clipRight;
        my $clipHeight = $height - $clipTop  - $clipBottom;

        my $clipPath = $self->svgDocument->createElement('clipPath');
        $clipPath->setAttribute('id', 'document-clip-path');

        my $rect = $self->svgDocument->createElement('rect');
        $rect->setAttribute('x', sprintf('%g', $clipX));
        $rect->setAttribute('y', sprintf('%g', $clipY));
        $rect->setAttribute('width', sprintf('%g', $clipWidth));
        $rect->setAttribute('height', sprintf('%g', $clipHeight));

        $self->svgDefsElement->appendChild($clipPath);
        $clipPath->appendChild($rect);
        $self->clipPathElement($clipPath);

        $self->svgTopLevelGroupElement->setAttribute(
            'clip-path', 'url(#document-clip-path)'
        );
    } else {
        $self->svgTopLevelGroupElement->removeAttribute('clip-path');
    }
}

use List::Util qw(any);

sub drawGrid {
    my $self = shift;
    my %args = @_;
    my $x = $args{x};           # number, string, or PointSeries
    my $y = $args{y};           # number, string, or PointSeries
    my $lineType  = $args{lineType};
    my $isClosed = $args{isClosed};
    my $parentId  = $args{parentId};
    my $id = $args{id};

    my $xIsPointSeries = eval {
        $x->isa('My::Printable::Paper::2::PointSeries')
    };
    my $yIsPointSeries = eval {
        $y->isa('My::Printable::Paper::2::PointSeries')
    };

    my @xPt = $self->xx($x);
    my @yPt = $self->yy($y);

    my $group = $self->svgGroupElement(id => $id, parentId => $parentId);
    my $x1 = 0;
    my $x2 = $self->xx('width');
    my $y1 = 0;
    my $y2 = $self->yy('height');
    if ($isClosed) {
        $x1 = $xPt[0];
        $x2 = $xPt[scalar(@xPt) - 1];
        $y1 = $yPt[0];
        $y2 = $yPt[scalar(@yPt) - 1];
    }

    my $lineStyle = eval { $self->lineTypeHash->{$lineType}->style; };
    my $isDashed = eval { $lineStyle eq 'dashed' };
    my $isDotted = eval { $lineStyle eq 'dotted' };
    my $isDashedOrDotted = $isDashed || $isDotted;

    my $spacingX =
        $xIsPointSeries ? $self->xx($x->step) : $self->xx('gridSpacingX');
    my $spacingY =
        $yIsPointSeries ? $self->yy($y->step) : $self->yy('gridSpacingY');

    my $hDashLength;
    my $vDashLength;
    my $hDashSpacing;
    my $vDashSpacing;
    my $hDashLineStart;
    my $vDashLineStart;
    my $hDashCenterAt;
    my $vDashCenterAt;
    if ($isDashedOrDotted) {
        if ($isDashed) {
            $hDashLength = $spacingX / 2;
            $vDashLength = $spacingY / 2;
        }
        if ($isDotted) {
            $hDashLength = 0;
            $vDashLength = 0;
        }
        $hDashSpacing = $spacingX;
        $vDashSpacing = $spacingY;
        if (!$isClosed) {
            $hDashLineStart = $x1;
            $hDashCenterAt = $xPt[0];
            $vDashLineStart = $y1;
            $vDashCenterAt = $yPt[0];
        }
    }

    my %hDashArgs = $isDashedOrDotted ? (
        dashLength    => $hDashLength,
        dashSpacing   => $hDashSpacing,
        dashLineStart => $hDashLineStart,
        dashCenterAt  => $hDashCenterAt,
    ) : ();
    my %vDashArgs = $isDashedOrDotted ? (
        dashLength    => $vDashLength,
        dashSpacing   => $vDashSpacing,
        dashLineStart => $vDashLineStart,
        dashCenterAt  => $vDashCenterAt,
    ) : ();

    # vertical lines
    foreach my $x (@xPt) {
        $group->appendChild(
            $self->createSVGLine(
                x => $x, y1 => $y1, y2 => $y2, lineType => $lineType,
                %vDashArgs,
            )
        );
    }

    # horizontal lines
    foreach my $y (@yPt) {
        $group->appendChild(
            $self->createSVGLine(
                y => $y, x1 => $x1, x2 => $x2, lineType => $lineType,
                %hDashArgs,
            )
        );
    }
}

sub drawHorizontalLines {
    my $self = shift;
    my %args = @_;
    my $y  = $args{y};          # number, string, or PointSeries
    my $x1 = $args{x1} // '0pt from start'; # number or string
    my $x2 = $args{x2} // '0pt from end';   # number or string
    my $lineType = $args{lineType};
    my $parentId = $args{parentId};
    my $id = $args{id};

    my @yPt  = $self->yy($y);
    my $x1Pt = $self->xx($x1);
    my $x2Pt = $self->xx($x2);

    my $group = $self->svgGroupElement(id => $id, parentId => $parentId);
    foreach my $y (@yPt) {
        $group->appendChild(
            $self->createSVGLine(
                y => $y, x1 => $x1, x2 => $x2, lineType => $lineType,
            )
        );
    }
}

sub drawVerticalLines {
    my $self = shift;
    my %args = @_;
    my $x  = $args{x};          # number, string, or PointSeries
    my $y1 = $args{y1} // '0pt from start'; # number or string
    my $y2 = $args{y2} // '0pt from end';   # number or string
    my $lineType = $args{lineType};
    my $parentId = $args{parentId};
    my $id = $args{id};

    my @xPt  = $self->xx($x);
    my $y1Pt = $self->yy($y1);
    my $y2Pt = $self->yy($y2);

    my $group = $self->svgGroupElement(id => $id, parentId => $parentId);
    foreach my $x (@xPt) {
        $group->appendChild(
            $self->createSVGLine(
                x => $x, y1 => $y1, y2 => $y2, lineType => $lineType,
            )
        );
    }
}

sub write {
    my $self = shift;
    my %args = @_;
    my $format   = $args{format} // 'pdf'; # pdf, svg, or ps
    my $basename = $self->basename;
    if (!defined $basename) {
        die("write: basename must be specified");
    }
    return $self->writeSVG(%args) if $format eq 'svg';
    return $self->writePDF(%args) if $format eq 'pdf';
    return $self->writePS(%args)  if $format eq 'ps';
}

use File::Slurp qw(write_file);

has 'isGenerated' => (is => 'rw', default => sub { return {}; });

sub getBasePDFFilename {
    my $self = shift;
    return $self->basename . '.pdf';
}

sub getBasePSFilename {
    my $self = shift;
    return $self->basename . '.ps';
}

sub getSVGFilename {
    my $self = shift;
    return $self->basename . '.svg';
}

sub getPDFFilename {
    my ($self, $nup, $npages) = @_;
    my $filename = $self->basename;
    $filename .= sprintf('-%dup', $nup)    if $nup    != 1;
    $filename .= sprintf('-%dpg', $npages) if $npages != 1;
    $filename .= '.pdf';
    return $filename;
}

sub getPSFilename {
    my ($self, $nup, $npages) = @_;
    my $filename = $self->basename;
    $filename .= sprintf('-%dup', $nup)    if $nup    != 1;
    $filename .= sprintf('-%dpg', $npages) if $npages != 1;
    $filename .= '.ps';
    return $filename;
}

sub writeSVG {
    my $self = shift;
    my %args = @_;
    my $svgFilename = $self->getSVGFilename;
    return if $self->isGenerated->{$svgFilename};
    write_file($svgFilename, $self->toSVG) or die("write $svgFilename: $!\n");
    $self->isGenerated->{$svgFilename} = 1;
}

sub writeBasePDF {
    my $self = shift;
    return if $self->isGenerated->{$self->getBasePDFFilename};
    $self->writeSVG;
    $self->converter->exportSVG(
        $self->getSVGFilename,
        $self->getBasePDFFilename
    );
    $self->isGenerated->{$self->getBasePDFFilename} = 1;
}

sub writeBasePS {
    my $self = shift;
    return if $self->isGenerated->{$self->getBasePSFilename};
    $self->writeSVG;
    $self->converter->exportSVG(
        $self->getSVGFilename,
        $self->getBasePSFilename
    );
    $self->isGenerated->{$self->getBasePSFilename} = 1;
}

sub writePDF {
    my ($self, $nup, $npages) = @_;
    if ($nup != 1 && $nup != 2 && $nup != 4) {
        die("writePDF: nup must be 1, 2, or 4");
    }
    if ($npages != 1 && $npages != 2) {
        die("writePDF: npages must be 1 or 2");
    }
    $self->writeBasePDF();
    $self->converter->convertPDF(
        $self->getBasePDFFilename,
        $self->getPDFFilename($nup, $npages),
        $nup, $npages,
        $self->xx('width'),
        $self->yy('height'),
    );
}

sub writePS {
    my ($self, $nup, $npages) = @_;
    if ($nup != 1 && $nup != 2 && $nup != 4) {
        die("writePS: nup must be 1, 2, or 4");
    }
    if ($npages != 1 && $npages != 2) {
        die("writePS: npages must be 1 or 2");
    }
    $self->writeBasePS();
    $self->converter->convertPS(
        $self->getBasePSFilename,
        $self->getPSFilename($nup, $npages),
        $nup, $npages,
        $self->xx('width'),
        $self->yy('height'),
    );
}

sub pointSeries {
    my $self = shift;
    my %args = @_;
    my $id = $args{id};
    my $pointSeries = My::Printable::Paper::2::PointSeries->new(
        paper => $self,
        %args
    );
    $self->pointSeriesHash->{$id} = $pointSeries if defined $id;
    return $pointSeries;
}

sub xPointSeries {
    my $self = shift;
    return $self->pointSeries(axis => 'x', @_);
}

sub yPointSeries {
    my $self = shift;
    return $self->pointSeries(axis => 'y', @_);
}

sub lineType {
    my $self = shift;
    my %args = @_;
    my $id = $args{id};
    my $lineType = My::Printable::Paper::2::LineType->new(
        paper => $self,
        %args
    );
    $self->lineTypeHash->{$id} = $lineType if defined $id;
    return $lineType;
}

sub parseCoordinate {
    my $self = shift;
    my $value = shift;
    my $axis = shift;
    return My::Printable::Paper::2::Coordinate::parse($value, $axis, $self);
}

use List::Util qw(any);

sub parseUnit {
    my $self = shift;
    my $unit = shift;
    my $axis = shift;
    return My::Printable::Paper::2::Unit::parse($unit, $axis, $self);
}

use XML::LibXML;

sub startSVG {
    my $self = shift;
    $self->svgDocument();
    $self->svgRootElement();
    $self->svgDefsElement();
    $self->svgStyleElement();
    $self->svgTopLevelGroupElement();
    $self->setCSS();
    $self->updateClipPathElement();
}

sub setCSS {
    my $self = shift;
    $self->svgStyleElement->removeChildNodes();
    my $css = $self->getCSS;
    $css =~ s{\s+\z}{};
    $css = "\n" . $css . "\n  ";
    $self->svgStyleElement->appendTextNode($css);
}

sub getCSS {
    my $self = shift;
    my $result = '';
    foreach my $lineTypeName (sort keys %{$self->lineTypeHash}) {
        my $lineType = $self->lineTypeHash->{$lineTypeName};
        $result .= $lineType->getCSS;
    }
    return $result;
}

has groupsById => (is => 'rw', default => sub { return {}; });

sub svgGroupElement {
    my $self = shift;
    my %args = @_;
    my $id = $args{id};
    my $hasId = defined $id && $id =~ m{\S};

    if ($hasId) {
        my $group = $self->groupsById->{$id};
        return $group if $group;
    }

    my $parentId = $args{parentId};
    my $hasParentId = defined $parentId && $parentId =~ m{\S};

    my $parent = $hasParentId ? $self->groupsById->{$parentId} :
        $self->svgTopLevelGroupElement;

    my $group = $self->svgDocument->createElement('g');
    $group->setAttribute('id', $id) if $hasId;
    $parent->appendChild($group);

    $self->groupsById->{$id} = $group if $hasId;

    return $group;
}

sub createSVGLine {
    my $self = shift;
    my %args = @_;
    my $x1 = $args{x1} // $args{x};
    my $x2 = $args{x2} // $args{x};
    my $y1 = $args{y1} // $args{y};
    my $y2 = $args{y2} // $args{y};
    my $lineType = $args{lineType};
    my $attr = $args{attr};
    my $line = $self->svgDocument->createElement('line');
    $line->setAttribute('x1', sprintf('%.3f', $self->xx($x1)));
    $line->setAttribute('x2', sprintf('%.3f', $self->xx($x2)));
    $line->setAttribute('y1', sprintf('%.3f', $self->yy($y1)));
    $line->setAttribute('y2', sprintf('%.3f', $self->yy($y2)));
    if (defined $lineType) {
        $line->setAttribute('class', $lineType);
        my $hash = $self->lineTypeHash->{$lineType};
        my %args = %args;
        if ($hash && $hash->{style} eq 'dotted') {
            $args{dashLength} = 0;
            $args{dashSpacing} =
            $line->setAttribute('stroke-dasharray', strokeDashArray(%args));
            $line->setAttribute('stroke-dashoffset', strokeDashOffset(%args));
        }
        if ($hash && $hash->{style} eq 'dashed') {
            $line->setAttribute('stroke-dasharray', strokeDashArray(%args));
            $line->setAttribute('stroke-dashoffset', strokeDashOffset(%args));
        }
    }
    if (eval { ref $attr eq 'HASH' }) {
        foreach my $name (sort keys %$attr) {
            $line->setAttribute($name, $attr->{$name});
        }
    }
    return $line;
}

sub xx {
    my $self = shift;
    my $value = shift;
    return $self->coordinate($value, 'x');
}

sub yy {
    my $self = shift;
    my $value = shift;
    return $self->coordinate($value, 'y');
}

use Regexp::Common qw(number);

sub coordinate {
    my $self = shift;
    my $value = shift;
    my $axis = shift;
    my $multiple = 0;
    die("undefined coordinate") if !defined $value;
    if (eval { $value->isa('My::Printable::Paper::2::PointSeries') }) {
        my @points = $value->getPoints;
        return @points if wantarray;
        return \@points;
    }
    if (eval { ref $value eq 'ARRAY' }) {
        my @points = map { $self->coordinate($_, $axis) } @$value;
        return @points if wantarray;
        return \@points;
    }
    if ($value =~ m{^\s*$RE{num}{real}}) {
        return $self->parseCoordinate($value, $axis);
    }
    if ($self->can($value)) {
        return $self->coordinate($self->$value, $axis);
    }
    die("can't parse '$value' as coordinate(s)");
}

sub toSVG {
    my $self = shift;
    return $self->svgDocument->toString(2);
}

1;