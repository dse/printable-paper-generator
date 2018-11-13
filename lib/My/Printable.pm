package My::Printable;
use warnings;
use strict;
use v5.10.0;

use lib "$ENV{HOME}/git/dse.d/perl-class-thingy/lib";
use Class::Thingy;

use lib "$ENV{HOME}/git/dse.d/printable-paper/lib";
use My::Printable::Util qw(exclude round3);
use My::Printable::Unit;
use My::Printable::Papersizes;

use XML::LibXML;
use List::Util qw(min max);
use Data::Dumper qw(Dumper);
use YAML qw(Dump);
use JSON::PP;
use Clone qw(clone);

public papersize,  default => "letter";
public width,      default => 612;
public height,     default => 792;
public unit_type,  default => "imperial";
public color_type, default => "color";

public doc;
public root;

public canvas;
public ruling;
public left_margin;
public right_margin;
public bottom_margin;
public top_margin;
public x_origin;
public y_origin;

public unit;
public unit_x;
public unit_y;

public modifiers;
public modifiers_hash;

sub init {
    my ($self) = @_;
    $self->unit(My::Printable::Unit->new);
    $self->unit_x(My::Printable::Unit->new);
    $self->unit_y(My::Printable::Unit->new);
}

our $RULINGS;
BEGIN {
    my $unit_one_quarter = {
        DEFAULT      => { DEFAULT => "1/4in", metric => "6mm" },
        smaller      => { DEFAULT => "1/5in", metric => "5mm" },
        "4-per-inch" => { DEFAULT => "1/4in" },
        "5-per-inch" => { DEFAULT => "1/5in" },
        "1/4in"      => { DEFAULT => "1/4in" },
        "1/5in"      => { DEFAULT => "1/5in" },
        "6mm"        => { DEFAULT => "6mm" },
        "5mm"        => { DEFAULT => "5mm" },
    };
    my $unit_seyes = {
        DEFAULT      => { DEFAULT => "5/16in", metric => "8mm"  },
        "8mm"        => { DEFAULT => "5/16in", metric => "8mm"  },
        "10mm"       => { DEFAULT => "3/8in",  metric => "10mm" },
        "three-line" => { DEFAULT => "1/4in",  metric => "6mm"  },
    };
    my $unit_doane = {
        DEFAULT => {
            DEFAULT => "1/8in",
            smaller => "1/12in",
        },
        metric => {
            DEFAULT => "3mm",
            smaller => "2mm",
        },
    };
    my $left_margin = {
        DEFAULT => {
            DEFAULT => "1.25in",
            metric => "41mm",
        },
        smaller => {
            DEFAULT => "0.75in",
            metric => "16mm",
        }
    };
    my $margin_line_css_class = {
        DEFAULT => "red margin line",
        grayscale => "gray margin line",
    };
    my $seyes_bottom = {
        DEFAULT => "1in",
        metric => "28mm",
        smaller => {
            DEFAULT => "0.75in",
            metric => "19mm",
        },
    };
    my $seyes_top = {
        DEFAULT => "1.5in",
        metric => "37mm",
        smaller => {
            DEFAULT => "1in",
            metric => "24mm",
        },
    };

    $RULINGS = {
        quadrille => {
            unit => $unit_one_quarter,
            grid => {
                x_spacing => "1unit",
                y_spacing => "1unit",
                css_class => {
                    DEFAULT => {
                        DEFAULT => "x-thin blue line",
                        grayscale => "x-thin gray line",
                    },
                },
                x_snap_to => "margins",
                y_snap_to => "margins",
            },
        },
        doane => {
            unit => $unit_doane,
            grid => {
                x_spacing => "1unit",
                y_spacing => "1unit",
                css_class => {
                    DEFAULT => {
                        DEFAULT => "xx-thin blue line",
                        grayscale => "xx-thin gray line",
                    },
                },
                exclude => {
                    horizontal_lines => 1,
                },
                x_snap_to => "margins",
                y_snap_to => "margins",
            },
            horizontal_lines => {
                y_spacing => "3unit",
                bottom => "2unit",
                css_class => {
                    DEFAULT => "blue line",
                    grayscale => "gray line",
                },
                snap_to => "grid",
            },
            left_margin_line => {
                x => "7/8in",
                snap_to => "grid",
            },
        },
        dot_grid => {
            unit => $unit_one_quarter,
            grid => {
                dots => 1,
                x_spacing => "1unit",
                y_spacing => "1unit",
                css_class => {
                    DEFAULT => "blue dot",
                    grayscale => "gray dot",
                },
                x_snap_to => "margins",
                y_snap_to => "margins",
            },
            left_margin_line => {
                x => $left_margin,
                snap_to => "grid",
                css_class => $margin_line_css_class,
            },
        },
        line_dot_grid => {
            unit => $unit_one_quarter,
            grid => {
                dots => 1,
                x_spacing => "1unit",
                y_spacing => "1unit",
                css_class => {
                    DEFAULT => {
                        DEFAULT => "semi-thick blue dot",
                        grayscale => "semi-thick gray dot",
                    },
                    "thinner-dots" => {
                        DEFAULT => "blue dot",
                        grayscale => "gray dot",
                    },
                    "x-thinner-dots" => {
                        DEFAULT => "semi-thin blue dot",
                        grayscale => "semi-thin gray dot",
                    },
                },
                top => $seyes_top,
            },
            horizontal_lines => {
                y_spacing => "1unit",
                top => $seyes_top,
                css_class => {
                    DEFAULT => {
                        DEFAULT => "thin blue line",
                        grayscale => "thin gray line",
                    },
                    "thinner-lines" => {
                        DEFAULT => "x-thin blue line",
                        grayscale => "x-thin gray line",
                    },
                    "x-thinner-lines" => {
                        DEFAULT => "xx-thin blue line",
                        grayscale => "xx-thin gray line",
                    },
                },
            },
            left_margin_line => {
                x => $left_margin,
                snap_to => "grid",
                css_class => $margin_line_css_class,
            },
        },
        line_dot_graph => {
            unit => $unit_seyes,
            grid => {
                dots => 1,
                x_spacing => "1unit",
                y_spacing => "1/4unit",
                css_class => {
                    DEFAULT => "thin blue dot",
                    grayscale => "thin gray dot",
                },
                exclude => {
                    horizontal_lines => 1,
                },
            },
            horizontal_lines => {
                y_spacing => "1unit",
                snap_to => "margins",
                bottom => $seyes_bottom,
                top => $seyes_top,
                css_class => {
                    DEFAULT => "thin blue line",
                    grayscale => "thin gray line",
                },
            },
            left_margin_line => {
                x => $left_margin,
                snap_to => "grid",
                css_class => $margin_line_css_class,
            },
        },
        seyes => {
            unit => $unit_seyes,
            horizontal_lines => {
                y_spacing => "1unit",
                bottom => $seyes_bottom,
                top => $seyes_top,
                css_class => {
                    DEFAULT => "blue line",
                    grayscale => "gray line",
                },
                minor => {
                    every => {
                        DEFAULT => 4,
                        "three-line" => 3,
                    },
                    extra => {
                        DEFAULT => {
                            bottom => 2,
                            top => 3,
                        },
                        "three-line" => {
                            bottom => 1,
                            top => 2,
                        },
                    },
                    css_class => {
                        DEFAULT => {
                            DEFAULT => "thin blue line",
                            grayscale => "thin gray line",
                        },
                        "thinner-grid" => {
                            DEFAULT => "x-thin blue line",
                            grayscale => "x-thin gray line",
                        },
                    },
                },
            },
            additional_horizontal_lines => [
                {
                    DEFAULT => {
                        position => "top",
                        y => {
                            DEFAULT => "0.5in",
                            metric => "13mm",
                            smaller => {
                                DEFAULT => "0.5in",
                                metric => "13mm",
                            },
                        },
                        snap_to => {
                            DEFAULT => "horizontal_lines",
                            smaller => "minor_horizontal_lines",
                        },
                        css_class => {
                            DEFAULT => {
                                DEFAULT => "thin blue line",
                                grayscale => "thin gray line",
                            },
                            "thinner-grid" => {
                                DEFAULT => "x-thin blue line",
                                grayscale => "x-thin gray line",
                            },
                        },
                    },
                },
                {
                    DEFAULT => {
                        position => "bottom",
                        y => {
                            DEFAULT => "0.5in",
                            metric => "12mm",
                            smaller => {
                                DEFAULT => "0.3125in",
                                metric => "9mm",
                            }
                        },
                        snap_to => {
                            DEFAULT => "horizontal_lines",
                            smaller => "minor_horizontal_lines",
                        },
                        css_class => {
                            DEFAULT => {
                                DEFAULT => "blue line stroke-linecap-butt",
                                grayscale => "gray line stroke-linecap-butt",
                            },
                        },
                        '!even-page' => {
                            right => {
                                x => "1unit",
                                snap_to => "vertical_lines",
                            },
                            width => "3unit",
                        },
                        '=even-page' => {
                            left => {
                                x => $left_margin,
                                snap_to => "vertical_lines",
                            },
                            width => "-3unit",
                            '=smaller' => {
                                width => "3unit",
                            },
                        },
                    },
                },
            ],
            vertical_lines => {
                x_spacing => {
                    DEFAULT => "1unit",
                    "wider-grid" => "1.5units",
                },
                snap_to => "margins",
                css_class => {
                    DEFAULT => {
                        DEFAULT => "thin blue line",
                        grayscale => "thin gray line",
                    },
                    "thinner-grid" => {
                        DEFAULT => "x-thin blue line",
                        grayscale => "x-thin gray line",
                    },
                },
                left => $left_margin,
            },
            left_margin_line => {
                x => $left_margin,
                snap_to => "vertical_lines",
                css_class => $margin_line_css_class,
            },
        },
    };
}

sub output_yaml {
    my ($self) = @_;
    my $string = Dump($RULINGS);
    print $string;
}

sub output_json {
    my ($self) = @_;
    my $json = JSON::PP->new->ascii(1)->pretty(1)->allow_nonref(1)->space_before(0)->indent_length(2);
    my $string = $json->encode($RULINGS);
    print $string;
}

sub output_perl {
    my ($self) = @_;
    local $Data::Dumper::Indent = 1; # standard indentation
    local $Data::Dumper::Trailingcomma = 1;
    local $Data::Dumper::Terse = 1; # output just the structure
    print Dumper($RULINGS);
}

sub set_papersize {
    my ($self, $spec) = @_;
    my ($name, $width, $height, $type) = My::Printable::PaperSizes->parse($spec);
    $self->unit_type($type);
    $self->papersize($name);
    $self->width($width);
    $self->height($height);
    $self->unit_x->set_percentage_basis($width);
    $self->unit_y->set_percentage_basis($height);
}

sub set_width {
    my ($self, $value) = @_;
    my ($pt, $type) = $self->unit->pt($value);
    $self->unit_type($type);
    $self->width($pt);
    $self->papersize(undef);
    $self->unit_x->set_percentage_basis($pt);
}

sub set_height {
    my ($self, $value) = @_;
    my ($pt, $type) = $self->unit->pt($value);
    $self->unit_type($type);
    $self->height($pt);
    $self->papersize(undef);
    $self->unit_y->set_percentage_basis($pt);
}

sub set_modifiers {
    my ($self, @modifiers) = @_;
    @modifiers = grep { defined $_ } @modifiers;
    my %modifiers = map { ($_, 1) } @modifiers;
    $self->modifiers(\@modifiers);
    $self->modifiers_hash(\%modifiers);
}

sub generate_paper {
    my ($self, $ruling_name, %args) = @_;

    $ruling_name =~ s{-}{_}g;

    my $ruling = $RULINGS->{$ruling_name};
    if (!$ruling) {
        die("No such ruling: $ruling_name\n");
    }
    $self->ruling($ruling);

    $self->unit->delete_unit("unit");
    $self->unit_x->delete_unit("unit");
    $self->unit_y->delete_unit("unit");
    my $ruling_unit = $self->ruling_get("unit");
    if (defined $ruling_unit) {
        my $unit_pt = $self->unit->pt($ruling_unit);
        my %options = (
            aka => "units",
        );
        $self->unit->add_unit("unit", $unit_pt, %options);
        $self->unit_x->add_unit("unit", $unit_pt, %options);
        $self->unit_y->add_unit("unit", $unit_pt, %options);
    }

    my $width  = $self->width;
    my $height = $self->height;

    my $ruling_left_margin   = $self->ruling_get("left_margin")   // 0;
    my $ruling_right_margin  = $self->ruling_get("right_margin")  // 0;
    my $ruling_bottom_margin = $self->ruling_get("bottom_margin") // 0;
    my $ruling_top_margin    = $self->ruling_get("top_margin")    // 0;
    my $ruling_x_origin      = $self->ruling_get("x_origin") // "50%";
    my $ruling_y_origin      = $self->ruling_get("y_origin") // "50%";

    my $left_margin  = $self->unit_x->pt($ruling_left_margin);
    my $right_margin = $self->width - $self->unit_x->pt($ruling_right_margin);

    my $bottom_margin = $self->unit_y->pt($ruling_bottom_margin);
    my $top_margin    = $self->height - $self->unit_y->pt($ruling_top_margin);

    my $x_origin = $self->unit_x->pt($ruling_x_origin);
    my $y_origin = $self->unit_y->pt($ruling_y_origin);

    $self->left_margin($left_margin);
    $self->right_margin($right_margin);
    $self->bottom_margin($bottom_margin);
    $self->top_margin($top_margin);
    $self->x_origin($x_origin);
    $self->y_origin($y_origin);

    my $doc = $self->create_document;
    my $root = $self->root;

    my $style = $self->create_style_element;
    $root->appendChild($style);

    my $canvas = $self->canvas({});
    $canvas->{grid}                        = {};
    $canvas->{horizontal_lines}            = {};
    $canvas->{additional_horizontal_lines} = [];
    $canvas->{vertical_lines}              = {};
    $canvas->{margin_lines}                = {};

    # Compute points.
    $self->compute_grid;

    $self->compute_vertical_lines;
    $self->compute_horizontal_lines;
    $self->chop_vertical_lines;
    $self->chop_horizontal_lines;
    $self->compute_minor_vertical_lines;
    $self->compute_minor_horizontal_lines;

    $self->compute_margin_lines;
    $self->compute_additional_horizontal_lines;

    # Secondary processing.
    $self->chop_grid;

    $self->exclude_from_minor_vertical_lines;
    $self->exclude_from_minor_horizontal_lines;

    $self->snap_margin_lines;
    $self->exclude_grid_points;

    # Draw everything.
    $self->draw_grid;
    $self->draw_minor_vertical_lines;
    $self->draw_minor_horizontal_lines;
    $self->draw_vertical_lines;
    $self->draw_horizontal_lines;

    $self->draw_additional_horizontal_lines;
    $self->draw_margin_lines;

    print $doc->toString(1);
}

sub compute_grid {
    my ($self) = @_;
    my $canvas_grid = $self->canvas->{grid};
    if ($self->ruling_get("grid")) {
        my $dg_x_spacing = $self->ruling_get("grid", "x_spacing") // "1unit";
        my $dg_y_spacing = $self->ruling_get("grid", "y_spacing") // "1unit";
        my $dg_x_snap_to = $self->ruling_get("grid", "x_snap_to");
        my $dg_y_snap_to = $self->ruling_get("grid", "y_snap_to");
        my $x_spacing = $canvas_grid->{x_spacing} = $self->unit_x->pt($dg_x_spacing);
        my $y_spacing = $canvas_grid->{y_spacing} = $self->unit_y->pt($dg_y_spacing);
        $canvas_grid->{x} = $self->get_points(
            axis => "x",
            spacing => $x_spacing,
            min => $self->left_margin,
            max => $self->right_margin,
            origin => $self->x_origin,
            snap_to => $dg_x_snap_to,
        );
        $canvas_grid->{y} = $self->get_points(
            axis => "y",
            spacing => $y_spacing,
            min => $self->bottom_margin,
            max => $self->top_margin,
            origin => $self->y_origin,
            snap_to => $dg_y_snap_to,
        );
    }
}

sub compute_horizontal_lines {
    my ($self) = @_;
    my $canvas_horizontal_lines = $self->canvas->{horizontal_lines};
    my $canvas_grid = $self->canvas->{grid};
    if ($self->ruling_get("horizontal_lines")) {
        my $hl_y_spacing = $self->ruling_get("horizontal_lines", "y_spacing") // "1unit";
        my $y_spacing = $canvas_horizontal_lines->{y_spacing} = $self->unit_y->pt($hl_y_spacing);
        my $our_y_origin = $self->y_origin;
        my $snap_to = $self->ruling_get("horizontal_lines", "snap_to");
        if ($self->ruling_get("grid")) {
            $our_y_origin = $canvas_grid->{y}->[0];
            my $bottom = $self->ruling_get('horizontal_lines', 'bottom');
            my $top    = $self->ruling_get('horizontal_lines', 'top');
            if (defined $bottom && !defined $top) {
                $our_y_origin = $self->unit_y->pt($bottom);
                $snap_to = "grid";
            }
            if (defined $top && !defined $bottom) {
                $our_y_origin = $self->unit_y->pt($top);
                $snap_to = "grid";
            }
        }
        $canvas_horizontal_lines->{y} = $self->get_points(
            axis => "y",
            spacing => $y_spacing,
            min => $self->bottom_margin,
            max => $self->top_margin,
            origin => $our_y_origin,
            snap_to => $snap_to,
        );
        $canvas_horizontal_lines->{unchopped_y} = $self->get_points(
            axis => "y",
            spacing => $y_spacing,
            min => $self->bottom_margin,
            max => $self->top_margin,
            origin => $our_y_origin,
            snap_to => $snap_to,
        );
    }
}

sub compute_additional_horizontal_lines {
    my ($self) = @_;
    my $canvas_additional_horizontal_lines = $self->canvas->{additional_horizontal_lines} //= [];
    my $ahls = $self->ruling_get("additional_horizontal_lines");
    return if !$ahls || ref $ahls ne "ARRAY";
    foreach my $ahl (@$ahls) {
        $ahl = $self->get($ahl);
        next if !$ahl;

        my $ahl_position     = $self->get($ahl, "position");
        my $ahl_x            = $self->get($ahl, "x");
        my $ahl_y            = $self->get($ahl, "y");
        my $ahl_snap_to      = $self->get($ahl, "snap_to");
        my $ahl_left         = $self->get($ahl, "left");
        my $ahl_right        = $self->get($ahl, "right");
        my $ahl_left_x       = $self->get($ahl, "left", "x");
        my $ahl_right_x      = $self->get($ahl, "right", "x");
        my $ahl_left_snap_to  = $self->get($ahl, "left", "snap_to");
        my $ahl_right_snap_to = $self->get($ahl, "right", "snap_to");
        my $ahl_width        = $self->get($ahl, "width");
        my $ahl_css_class        = $self->get($ahl, "css_class") // $self->ruling_get("horizontal_lines", "css_class");

        my $y;
        if ($ahl_position eq "bottom") {
            $y = $self->unit_y->pt($ahl_y);
        } elsif ($ahl_position eq "top") {
            $y = $self->height - $self->unit_y->pt($ahl_y);
        }
        if ($ahl_snap_to eq "horizontal_lines") {
            $y = $self->point_nearest($y, @{$self->canvas->{horizontal_lines}->{unchopped_y}});
        }

        my $x1;
        my $x2;
        if (defined $ahl_left) {
            $x1 = $self->unit_x->pt($ahl_left_x);
            if ($ahl_left_snap_to eq "vertical_lines") {
                $x1 = $self->point_nearest($x1, @{$self->canvas->{vertical_lines}->{unchopped_x}});
            }
        }
        if (defined $ahl_right) {
            $x2 = $self->width - $self->unit_x->pt($ahl_right_x);
            if ($ahl_right_snap_to eq "vertical_lines") {
                $x2 = $self->point_nearest($x2, @{$self->canvas->{vertical_lines}->{unchopped_x}});
            }
        }

        if (defined $ahl_left && !defined $ahl_right && defined $ahl_width) {
            $x2 = $x1 + $self->unit_x->pt($ahl_width);
        }
        if (defined $ahl_right && !defined $ahl_left && defined $ahl_width) {
            $x1 = $x2 - $self->unit_x->pt($ahl_width);
        }

        push(@{$canvas_additional_horizontal_lines}, {
            x1 => $x1,
            x2 => $x2,
            y => $y,
            css_class => $ahl_css_class,
        });
    }
}

sub compute_vertical_lines {
    my ($self) = @_;
    my $canvas_vertical_lines = $self->canvas->{vertical_lines};
    my $canvas_grid = $self->canvas->{grid};
    if ($self->ruling_get("vertical_lines")) {
        my $vl_x_spacing = $self->ruling_get("vertical_lines", "x_spacing") // "1unit";
        my $x_spacing = $canvas_vertical_lines->{x_spacing} = $self->unit_x->pt($vl_x_spacing);
        my $our_x_origin = $self->x_origin;
        if ($self->ruling_get("grid")) {
            $our_x_origin = $canvas_grid->{x}->[0];
        }
        $canvas_vertical_lines->{x} = $self->get_points(
            spacing => $x_spacing,
            min => $self->left_margin,
            max => $self->right_margin,
            origin => $our_x_origin,
            snap_to => $self->ruling_get("vertical_lines", "snap_to"),
        );
        $canvas_vertical_lines->{unchopped_x} = $self->get_points(
            spacing => $x_spacing,
            min => $self->left_margin,
            max => $self->right_margin,
            origin => $our_x_origin,
            snap_to => $self->ruling_get("vertical_lines", "snap_to"),
        );
    }
}

sub compute_margin_lines {
    my ($self) = @_;
    my $canvas_margin_lines = $self->canvas->{margin_lines};
    if ($self->ruling_get("left_margin_line")) {
        $canvas_margin_lines->{left}->{x} = $self->unit_x->pt($self->ruling_get("left_margin_line", "x"));
    }
}

sub chop_grid {
    my ($self) = @_;
    my $canvas_grid = $self->canvas->{grid};
    my $height = $self->height;
    my $width = $self->width;
    if ($self->ruling_get("grid")) {
        my $x = $canvas_grid->{x};
        my $y = $canvas_grid->{y};

        my $bottom = $self->ruling_get("grid", "bottom");
        my $top    = $self->ruling_get("grid", "top");
        my $left   = $self->ruling_get("grid", "left");
        my $right  = $self->ruling_get("grid", "right");

        if (defined $bottom) {
            my $bottom_y = $self->unit_y->pt($bottom);
            $bottom_y = $self->point_nearest($bottom_y, @$y);
            @$y = grep { $_ >= $bottom_y } @$y;
        }
        if (defined $top) {
            my $top_y = $height - $self->unit_y->pt($top);
            $top_y = $self->point_nearest($top_y, @$y);
            @$y = grep { $_ <= $top_y } @$y;
        }
        if (defined $left) {
            my $left_x = $self->unit_x->pt($left);
            $left_x = $self->point_nearest($left_x, @$x);
            @$x = grep { $_ >= $left_x } @$x;
        }
        if (defined $right) {
            my $right_x = $width - $self->unit_x->pt($right);
            $right_x = $self->point_nearest($right_x, @$x);
            @$x = grep { $_ <= $right_x } @$x;
        }
    }
}

sub chop_horizontal_lines {
    my ($self) = @_;
    my $canvas_horizontal_lines = $self->canvas->{horizontal_lines};
    my $height = $self->height;
    if ($self->ruling_get("horizontal_lines")) {
        my $y = $canvas_horizontal_lines->{y};

        my $bottom = $self->ruling_get("horizontal_lines", "bottom");
        if (defined $bottom) {
            my $bottom_y = $self->unit_y->pt($bottom);
            $bottom_y = $self->point_nearest($bottom_y, @$y);
            @$y = grep { $_ >= $bottom_y } @$y;
        }

        my $top = $self->ruling_get("horizontal_lines", "top");
        if (defined $top) {
            my $top_y = $height - $self->unit_y->pt($top);
            $top_y = $self->point_nearest($top_y, @$y);
            @$y = grep { $_ <= $top_y } @$y;
        }
    }
}

sub chop_vertical_lines {
    my ($self) = @_;
    my $canvas_vertical_lines = $self->canvas->{vertical_lines};
    my $width = $self->width;
    if ($self->ruling_get("vertical_lines")) {
        my $x = $canvas_vertical_lines->{x};

        my $left = $self->ruling_get("vertical_lines", "left");
        if (defined $left) {
            my $left_x = $self->unit_x->pt($left);
            $left_x = $self->point_nearest($left_x, @$x);
            @$x = grep { $_ >= $left_x } @$x;
        }

        my $right = $self->ruling_get("vertical_lines", "right");
        if (defined $right) {
            my $right_x = $width - $self->unit_x->pt($right);
            $right_x = $self->point_nearest($right_x, @$x);
            @$x = grep { $_ <= $right_x } @$x;
        }
    }
}

sub compute_minor_horizontal_lines {
    my ($self) = @_;
    my $canvas_horizontal_lines = $self->canvas->{horizontal_lines};
    if ($self->ruling_get("horizontal_lines", "minor")) {
        my $y = $canvas_horizontal_lines->{y};
        my $every        = $self->ruling_get("horizontal_lines", "minor", "every");
        my $extra_bottom = $self->ruling_get("horizontal_lines", "minor", "extra", "bottom") // 0;
        my $extra_top    = $self->ruling_get("horizontal_lines", "minor", "extra", "top")    // 0;
        my $y_bottom = min @$y;
        my $y_top    = max @$y;
        my $y_spacing = $canvas_horizontal_lines->{y_spacing} / $every;
        my $new_y_bottom = $y_bottom - ($extra_bottom + 0.5) * $y_spacing;
        my $new_y_top    = $y_top    + ($extra_top    + 0.5) * $y_spacing;
        my $minor_y = $canvas_horizontal_lines->{minor}->{y} = $self->get_points(
            spacing => $y_spacing,
            min => $new_y_bottom,
            max => $new_y_top,
            origin => $y_bottom
        );
    }
}

sub compute_minor_vertical_lines {
    my ($self) = @_;
    my $canvas_vertical_lines = $self->canvas->{vertical_lines};
    if ($self->ruling_get("vertical_lines", "minor")) {
        my $x = $canvas_vertical_lines->{x};
        my $every        = $self->ruling_get("vertical_lines", "minor", "every");
        my $extra_left   = $self->ruling_get("vertical_lines", "minor", "extra", "left")  // 0;
        my $extra_right  = $self->ruling_get("vertical_lines", "minor", "extra", "right") // 0;
        my $x_left  = min @$x;
        my $x_right = max @$x;
        my $x_spacing = $canvas_vertical_lines->{x_spacing} / $every;
        my $new_x_left  = $x_left  - ($extra_left  + 0.5) * $x_spacing;
        my $new_x_right = $x_right + ($extra_right + 0.5) * $x_spacing;
        my $minor_x = $canvas_vertical_lines->{minor}->{x} = $self->get_points(
            spacing => $x_spacing,
            min => $new_x_left,
            max => $new_x_right,
            origin => $x_left
        );
    }
}

sub exclude_from_minor_horizontal_lines {
    my ($self) = @_;
    my $canvas_horizontal_lines = $self->canvas->{horizontal_lines};
    if ($self->ruling_get("horizontal_lines", "minor")) {
        my $minor_y = $canvas_horizontal_lines->{minor}->{y};
        @$minor_y = exclude(@$minor_y, @{$canvas_horizontal_lines->{y}});
    }
}

sub exclude_from_minor_vertical_lines {
    my ($self) = @_;
    my $canvas_vertical_lines = $self->canvas->{vertical_lines};
    if ($self->ruling_get("vertical_lines", "minor")) {
        my $minor_x = $canvas_vertical_lines->{minor}->{x};
        @$minor_x = exclude(@$minor_x, @{$canvas_vertical_lines->{x}});
    }
}

sub snap_margin_lines {
    my ($self) = @_;
    my $canvas_margin_lines = $self->canvas->{margin_lines};
    my $canvas_grid = $self->canvas->{grid};
    my $canvas_vertical_lines = $self->canvas->{vertical_lines};
    if ($self->ruling_get("left_margin_line")) {
        my $snap_to = $self->ruling_get("left_margin_line", "snap_to");
        if (defined $snap_to) {
            if ($snap_to eq "grid" && $self->ruling_get("grid")) {
                $canvas_margin_lines->{left}->{x} = $self->point_nearest($canvas_margin_lines->{left}->{x},
                                                                         @{$canvas_grid->{x}});
            }
            if ($snap_to eq "vertical_lines" && $self->ruling_get("vertical_lines")) {
                $canvas_margin_lines->{left}->{x} = $self->point_nearest($canvas_margin_lines->{left}->{x},
                                                                         @{$canvas_vertical_lines->{x}});
            }
        }
    }
}

sub exclude_grid_points {
    my ($self) = @_;
    my $canvas_margin_lines = $self->canvas->{margin_lines};
    my $canvas_grid = $self->canvas->{grid};
    my $canvas_horizontal_lines = $self->canvas->{horizontal_lines};
    my $canvas_vertical_lines = $self->canvas->{vertical_lines};
    if ($self->ruling_get("grid")) {
        my $x = $canvas_grid->{x};
        my $y = $canvas_grid->{y};

        my $exclude_hl  = $self->ruling_get("grid", "exclude", "horizontal_lines");
        my $exclude_vl  = $self->ruling_get("grid", "exclude", "vertical_lines");
        my $exclude_mhl = $self->ruling_get("grid", "exclude", "minor_horizontal_lines");
        my $exclude_mvl = $self->ruling_get("grid", "exclude", "minor_vertical_lines");
        my $exclude_lml = $self->ruling_get("grid", "exclude", "left_margin_line");

        my $has_hl      = $self->ruling_get("horizontal_lines");
        my $has_vl      = $self->ruling_get("vertical_lines");
        my $has_mhl     = $self->ruling_get("horizontal_lines", "minor");
        my $has_mvl     = $self->ruling_get("vertical_lines", "minor");
        my $has_lml     = $self->ruling_get("left_margin_line");

        # keep original boundaries in case grid is enclosed.
        $canvas_grid->{min_x} = min(@{$x});
        $canvas_grid->{max_x} = max(@{$x});
        $canvas_grid->{min_y} = min(@{$y});
        $canvas_grid->{max_y} = max(@{$y});

        if ($has_hl && $exclude_hl) {
            @$y = exclude(@$y, @{$canvas_horizontal_lines->{y}});
        }
        if ($has_mhl && $exclude_mhl) {
            @$y = exclude(@$y, @{$canvas_horizontal_lines->{minor}->{y}});
        }
        if ($has_vl && $exclude_vl) {
            @$x = exclude(@$x, @{$canvas_vertical_lines->{x}});
        }
        if ($has_mvl && $exclude_mvl) {
            @$x = exclude(@$x, @{$canvas_vertical_lines->{minor}->{x}});
        }
        if ($has_lml && $exclude_lml) {
            @$x = exclude(@$x, ($canvas_margin_lines->{left}->{x}));
        }
    }
}

sub draw_grid {
    my ($self) = @_;
    my $canvas_grid = $self->canvas->{grid};
    my $dots = $self->ruling_get("grid", "dots");
    if ($self->ruling_get("grid")) {
        my $layer = $self->layer("grid");
        if ($dots) {
            foreach my $x (@{$canvas_grid->{x}}) {
                foreach my $y (@{$canvas_grid->{y}}) {
                    my $line = $self->create_line(
                        x => $x, y => $y,
                        css_class => $self->ruling_get("grid", "css_class") // "thin blue dot",
                    );
                    $layer->appendChild($line);
                }
            }
        } else {
            my $enclosed = $self->ruling_get("grid", "enclosed");
            my $x_css_class = $self->ruling_get("grid", "x_css_class") // $self->ruling_get("grid", "css_class") // "thin blue line";
            my $y_css_class = $self->ruling_get("grid", "y_css_class") // $self->ruling_get("grid", "css_class") // "thin blue line";
            my ($x1, $x2);
            my ($y1, $y2);
            if ($enclosed) {
                $x1 = $canvas_grid->{min_x};
                $x2 = $canvas_grid->{max_x};
                $y1 = $canvas_grid->{min_y};
                $y2 = $canvas_grid->{max_y};
            } else {
                $x1 = $self->left_margin;
                $x2 = $self->right_margin;
                $y1 = $self->bottom_margin;
                $y2 = $self->top_margin;
            }
            foreach my $x (@{$canvas_grid->{x}}) {
                my $line = $self->create_line(
                    y1 => $y1, y2 => $y2, x => $x,
                    css_class => $x_css_class,
                );
                $layer->appendChild($line);
            }
            foreach my $y (@{$canvas_grid->{y}}) {
                my $line = $self->create_line(
                    x1 => $x1, x2 => $x2, y => $y,
                    css_class => $y_css_class,
                );
                $layer->appendChild($line);
            }
        }
    }
}

sub draw_horizontal_lines {
    my ($self) = @_;
    my $canvas_horizontal_lines = $self->canvas->{horizontal_lines};
    if ($self->ruling_get("horizontal_lines")) {
        my $layer = $self->layer("horizontal-lines");
        foreach my $y (@{$canvas_horizontal_lines->{y}}) {
            my $x1 = $self->left_margin;
            my $x2 = $self->right_margin;
            my $line = $self->create_line(
                x1 => $x1, x2 => $x2, y => $y,
                css_class => $self->ruling_get("horizontal_lines", "css_class") // "thin blue line",
            );
            $layer->appendChild($line);
        }
    }
}

sub draw_additional_horizontal_lines {
    my ($self) = @_;
    my $canvas_additional_horizontal_lines = $self->canvas->{additional_horizontal_lines};
    my $layer = $self->layer("additional-horizontal-lines");
    if ($self->ruling_get("horizontal_lines")) {
        foreach my $line (@{$canvas_additional_horizontal_lines}) {
            my $y  = $line->{y};
            my $x1 = $line->{x1} // $self->left_margin;
            my $x2 = $line->{x2} // $self->right_margin;
            my $line = $self->create_line(
                x1 => $x1,
                x2 => $x2,
                y => $y,
                css_class => $line->{css_class} // "thin blue line"
            );
            $layer->appendChild($line);
        }
    }
}

sub draw_minor_horizontal_lines {
    my ($self) = @_;
    my $canvas_horizontal_lines = $self->canvas->{horizontal_lines};
    if ($self->ruling_get("horizontal_lines", "minor")) {
        my $layer = $self->layer("minor-horizontal-lines");
        my $minor = $canvas_horizontal_lines->{minor};
        if (defined $minor) {
            my $x1 = $self->left_margin;
            my $x2 = $self->right_margin;
            foreach my $y (@{$minor->{y}}) {
                my $line = $self->create_line(
                    x1 => $x1, x2 => $x2, y => $y,
                    css_class => $self->ruling_get("horizontal_lines", "minor", "css_class") // "x-thin blue line",
                );
                $layer->appendChild($line);
            }
        }
    }
}

sub draw_vertical_lines {
    my ($self) = @_;
    my $canvas_vertical_lines = $self->canvas->{vertical_lines};
    if ($self->ruling_get("vertical_lines")) {
        my $layer = $self->layer("vertical-lines");
        my $y1 = $self->bottom_margin;
        my $y2 = $self->top_margin;
        foreach my $x (@{$canvas_vertical_lines->{x}}) {
            my $line = $self->create_line(
                y1 => $y1, y2 => $y2, x => $x,
                css_class => $self->ruling_get("vertical_lines", "css_class") // "thin blue line",
            );
            $layer->appendChild($line);
        }
    }
}

sub draw_minor_vertical_lines {
    my ($self) = @_;
    my $canvas_vertical_lines = $self->canvas->{vertical_lines};
    if ($self->ruling_get("vertical_lines", "minor")) {
        my $layer = $self->layer("minor-vertical-lines");
        my $minor = $canvas_vertical_lines->{minor};
        if (defined $minor) {
            my $y1 = $self->bottom_margin;
            my $y2 = $self->top_margin;
            foreach my $x (@{$minor->{x}}) {
                my $line = $self->create_line(
                    y1 => $y1, y2 => $y2, x => $x,
                    css_class => $self->ruling_get("vertical_lines", "minor", "css_class") // "x-thin blue line",
                );
                $layer->appendChild($line);
            }
        }
    }
}

sub draw_margin_lines {
    my ($self) = @_;
    my $canvas_margin_lines = $self->canvas->{margin_lines};
    if ($self->ruling_get("left_margin_line")) {
        my $layer = $self->layer("margin-lines");
        my $margin_line = $self->create_line(
            x => $canvas_margin_lines->{left}->{x},
            y1 => $self->bottom_margin,
            y2 => $self->top_margin,
            css_class => $self->ruling_get("left_margin_line", "css_class") // "red margin line",
        );
        $layer->appendChild($margin_line);
    }
}

sub get_points {
    my ($self, %args) = @_;
    my $spacing = $args{spacing};
    my $origin  = $args{origin};
    my $min     = $args{min};
    my $max     = $args{max};
    my $axis    = $args{axis};
    my $snap_to = delete $args{snap_to};

    if (defined $snap_to) {
        if ($snap_to eq "margins") {
            my @points1 = $self->get_points(%args);
            my %args2 = %args;
            $args2{origin} += $spacing / 2;
            if ($args2{origin} > $max) {
                $args2{origin} -= $spacing;
            }
            my @points2 = $self->get_points(%args2);
            my $min1 = $points1[0];
            my $min2 = $points2[0];
            if ($min1 < $min2) {
                return @points1 if wantarray;
                return \@points1;
            }
            return @points2 if wantarray;
            return \@points2;
        }
        if ($snap_to eq "grid" && $self->ruling_get("grid")) {
            my $canvas_grid = $self->canvas->{grid};
            my %args2 = %args;
            if ($axis eq "x") {
                $args2{origin} = $self->point_nearest($args2{origin}, @{$canvas_grid->{x}});
            } elsif ($axis eq "y") {
                $args2{origin} = $self->point_nearest($args2{origin}, @{$canvas_grid->{y}});
            }
            my @points2 = $self->get_points(%args2);
            return @points2 if wantarray;
            return \@points2;
        }
    }

    my @points = ($origin);
    $spacing = $self->unit->pt($spacing);
    my $x;
    for ($x = $origin + $spacing; $x <= $max; $x += $spacing) {
        push(@points, $x);
    }
    for ($x = $origin - $spacing; $x >= $min; $x -= $spacing) {
        unshift(@points, $x);
    }
    return @points if wantarray;
    return \@points;
}

# point_nearest($x, @x) returns the element of @x that is nearest $x.
sub point_nearest {
    my ($self, $x, @points) = @_;
    my @dist = map { abs($x - $_) } @points;
    my $mindist = min(@dist);
    for (my $i = 0; $i < scalar @points; $i += 1) {
        if ($mindist == $dist[$i]) {
            return $points[$i];
        }
    }
    return undef;       # should NEVER happen.
}

sub create_line {
    my ($self, %args) = @_;
    my $doc = $self->doc;
    my $line = $doc->createElement("line");
    my $x1 = $args{x1} // $args{x};
    my $x2 = $args{x2} // $args{x};
    my $y1 = $args{y1} // $args{y};
    my $y2 = $args{y2} // $args{y};

    # Our internal coordinate system is bottom = 0.
    # But SVG's is top = 0.
    $y1 = $self->height - $y1;
    $y2 = $self->height - $y2;

    $line->setAttribute("x1", round3($x1));
    $line->setAttribute("x2", round3($x2));
    $line->setAttribute("y1", round3($y1));
    $line->setAttribute("y2", round3($y2));
    $line->setAttribute("class", $args{css_class}) if defined $args{css_class};
    return $line;
}

sub create_document {
    my ($self) = @_;
    my $width = $self->width;
    my $height = $self->height;
    my $viewBox = sprintf("%s %s %s %s",
                          map { round3($_) } (0, 0, $width, $height));
    my $doc = $self->doc(XML::LibXML::Document->new("1.0", "UTF-8"));
    my $root = $self->root($doc->createElement("svg"));
    $root->setAttribute("width", round3($width) . "pt");
    $root->setAttribute("height", round3($height) . "pt");
    $root->setAttribute("viewBox", $viewBox);
    $root->setAttribute("xmlns", "http://www.w3.org/2000/svg");
    $doc->setDocumentElement($root);
    return $doc;
}

sub create_style_element {
    my ($self, $css) = @_;

    my $xx_thin_line_stroke_width    = $self->unit->pt("2/600in");
    my $x_thin_line_stroke_width     = $self->unit->pt("3/600in");
    my $thin_line_stroke_width       = $self->unit->pt("4/600in");
    my $semi_thin_line_stroke_width  = $self->unit->pt("4.9/600in");
    my $line_stroke_width            = $self->unit->pt("6/600in");
    my $semi_thick_line_stroke_width = $self->unit->pt("7.35/600in");
    my $thick_line_stroke_width      = $self->unit->pt("9/600in");

    my $thin_dot_stroke_width        = $self->unit->pt("4/300in");
    my $semi_thin_dot_stroke_width   = $self->unit->pt("4.9/300in");
    my $dot_stroke_width             = $self->unit->pt("6/300in");
    my $semi_thick_dot_stroke_width  = $self->unit->pt("7.35/300in");
    my $thick_dot_stroke_width       = $self->unit->pt("9/300in");

    $css //= <<"EOF";
            .line, .dot { stroke-linecap: round; }
            .stroke-linecap-butt { stroke-linecap: butt; }

            .line            { stroke-width: ${line_stroke_width}pt; }
            .line.xx-thin    { stroke-width: ${xx_thin_line_stroke_width}pt; }
            .line.x-thin     { stroke-width: ${x_thin_line_stroke_width}pt; }
            .line.thin       { stroke-width: ${thin_line_stroke_width}pt; }
            .line.thick      { stroke-width: ${thick_line_stroke_width}pt; }
            .line.semi-thin  { stroke-width: ${semi_thin_line_stroke_width}pt; }
            .line.semi-thick { stroke-width: ${semi_thick_line_stroke_width}pt; }

            .dot             { stroke-width: ${dot_stroke_width}pt; }
            .dot.thin        { stroke-width: ${thin_dot_stroke_width}pt; }
            .dot.thick       { stroke-width: ${thick_dot_stroke_width}pt; }
            .dot.semi-thin   { stroke-width: ${semi_thin_dot_stroke_width}pt; }
            .dot.semi-thick  { stroke-width: ${semi_thick_dot_stroke_width}pt; }

            .stroke-1     { stroke-width: 0.12pt; } /* 1/600 in */
            .stroke-2     { stroke-width: 0.24pt; }
            .stroke-3     { stroke-width: 0.36pt; }
            .stroke-4     { stroke-width: 0.48pt; }
            .stroke-5     { stroke-width: 0.60pt; }
            .stroke-6     { stroke-width: 0.72pt; }
            .stroke-7     { stroke-width: 0.84pt; }
            .stroke-8     { stroke-width: 0.96pt; }
            .stroke-9     { stroke-width: 1.08pt; }
            .stroke-10    { stroke-width: 1.20pt; }

            .blue  { stroke: #b3b3ff; }
            .red   { stroke: #ff9999; }
            .green { stroke: #b3ffb3; }
            .gray  { stroke: #b3b3b3; }

            .light.blue  { stroke: #d9d9ff; }
            .light.red   { stroke: #ffcccc; }
            .light.green { stroke: #d9ffd9; }
            .light.gray  { stroke: #d9d9d9; }

            .dark.blue  { stroke: #6767ff; }
            .dark.red   { stroke: #ff3333; }
            .dark.green { stroke: #67ff67; }
            .dark.gray  { stroke: #676767; }

            .alternate-blue  { stroke: #6767ff; opacity: 0.5; }
            .alternate-red   { stroke: #ff3333; opacity: 0.5; }
            .alternate-green { stroke: #67ff67; opacity: 0.5; }
            .alternate-gray  { stroke: #676767; opacity: 0.5; }
EOF
    my $doc = $self->doc;
    my $style = $doc->createElement("style");
    $style->appendText($css);
    return $style;
}

sub create_g_element {
    my ($self, $id) = @_;
    my $doc = $self->doc;
    my $g = $doc->createElement("g");
    $g->setAttribute("id", $id);
    return $g;
}

sub layer {
    my ($self, $id) = @_;
    my $doc = $self->doc;
    my $root = $self->root;
    my ($layer) = $doc->findnodes("//*[\@id='" . $id . "']");
    if ($layer) {
        return $layer;
    }
    $layer = $self->create_g_element($id);
    $root->appendChild($layer);
    return $layer;
}

sub value {
    my ($self, $value) = @_;
    return undef if !defined $value;
    return $value if ref $value ne "HASH";
    return $value if !exists $value->{DEFAULT};
    my $valuehash = $value;
    $value = $valuehash->{DEFAULT};
    foreach my $modifier (@{$self->modifiers}, $self->unit_type, $self->color_type) {
        if (exists $valuehash->{$modifier}) {
            $value = $valuehash->{$modifier};
        }
    }
    return $self->value($value);
}

sub ruling_get {
    my ($self, @props) = @_;
    return $self->get($self->{ruling}, @props);
}

sub get {
    my ($self, $o, $prop, @other_props) = @_;
    if (!defined $o) {
        return undef;
    }
    if (ref $o ne "HASH") {
        if (defined $prop) {
            return undef;
        }
        return $o;
    }
    $o = clone($o);

    if (exists $o->{DEFAULT}) {
        my $next = $o->{DEFAULT};
        foreach my $modifier (@{$self->modifiers},
                              $self->unit_type,
                              $self->color_type) {
            if (exists $o->{$modifier}) {
                $next = $o->{$modifier};
            }
        }
        return $self->get($next, $prop, @other_props);
    }

    my @negative_modifiers = sort map { substr($_, 1) } grep { m{^\!} } keys %$o;
    my @positive_modifiers = sort map { substr($_, 1) } grep { m{^\=} } keys %$o;
    @negative_modifiers = grep { !exists($self->modifiers_hash->{$_}) } @negative_modifiers;
    @positive_modifiers = grep {  exists($self->modifiers_hash->{$_}) } @positive_modifiers;
    my @modifiers = (@negative_modifiers, @positive_modifiers);
    @modifiers = sort @modifiers;
    foreach my $modifier (@modifiers) {
        my $apply;
        if ($self->modifiers_hash->{$modifier}) {
            $apply = delete $o->{"=" . $modifier};
            delete $o->{"!" . $modifier};
        } else {
            $apply = delete $o->{"!" . $modifier};
            delete $o->{"=" . $modifier};
        }
        if (defined $apply) {
            if (ref $apply eq "HASH") {
                %$o = (%$o, %$apply);
            }
        }
    }

    if (!defined $prop) {
        return $o;
    }
    if (!defined $o->{$prop}) {
        return undef;
    }
    return $self->get($o->{$prop}, @other_props);
}

1;
