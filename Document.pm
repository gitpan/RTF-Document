package RTF::Document;
require 5.004;
require Exporter;

use vars qw(
    $VERSION
    %DOCINFO %PROPERTIES
    %FONTCLASSES %FONTPITCH
    %COLORNAMES
    %STYLETYPES
);
$VERSION = "0.6";

@ISA = qw(Exporter);
@EXPORT = qw();
@EXPORT_OK = qw();

use Carp;
use POSIX;
use Units::Type 0.32;

# $arg is a key to RTF control in hash value
sub _prop_decode
{
    my ($self, $hash, $arg) = @_;

    my $result = ${$hash}{$arg};

    unless (defined($result)) {
        carp "Don\'t know how to handle value \`$arg\'";
    }

    return $result;
}

sub _prop_style {
    my ($self, $code, $arg) = @_;
    $code = $arg;
    if (defined($arg)) {
        my @style_formatting = @{$self->{styles}->{decode_stylename($arg, '\s222')}};
        unless (defined(@style_formatting)) {
            carp "Style \`$arg\' is not defined";
            $code = decode_stylename("none");
        }
        foreach( @style_formatting ) {
            $code .= $_;
        }
    }
    return substr($code, 1);
}

# $arg is a unit of type (points, picas, inches) converted to twips
sub _prop_twips {
    my ($self, $code, $arg) = @_;
    return $code.POSIX::floor(Units::Type::convert($arg, "twips"));
}

# $arg is a unit of type (points, picas, inches) converted to half-points
sub _prop_halfpts {
    my ($self, $code, $arg) = @_;
    return $code.POSIX::floor(Units::Type::convert($arg, "half-points"));
}

# $arg is a string (which may need to be escaped)
sub _prop_pcdata {
    my ($self, $code, $arg) = @_;
    $arg =~ s/([\\\{\}])/\\$1/g;
    return $code." ".$arg;
}

# $arg is a raw value
sub _prop_raw {
    my ($self, $code, $arg) = @_;
    return $code.$arg;
}

# $arg is a an on/off indicator (0 = off, NZ = on)
sub _prop_onoff {
    my ($self, $code, $arg) = @_;
    if ($arg)
    {
        return $code;
    }
    else
    {
        return $code."0";
    }
}

# $arg is a an emit/don't emit indicator (0 = don't emit control, NZ = emit)
sub _prop_on {
    my ($self, $code, $arg) = @_;
    if ($arg)
    {
        return $code;
    }
    else
    {
        return undef;
    }
}

# Synopsis of %DOCINFO and %PROPERTIES
#   property => [ where, control, group, function ]
#     property = name of the property
#     where    = what section of the document this control is usually applied to
#     control	 = the control word used (if a hash, how to decode various controls)
#     group    = if non-zero, emit this as part of a group
#     function = what function to use to process this property
# Most properties follow the following naming scheme:
#  doc = document-wide properties (should be set only once)
#  sec = section properties
#  col = column properties (within a section)
#  par = paragraph properties

%DOCINFO = (
    # --- Document summary information
    doc_title		=> [ info,  'title', 	1, \&_prop_pcdata ],
    doc_author	=> [ info,  'author',	1, \&_prop_pcdata ],
    doc_subject	=> [ info,  'subject',	1, \&_prop_pcdata ],
    doc_manager	=> [ info,  'manager',	1, \&_prop_pcdata ],
    doc_company	=> [ info,  'company',	1, \&_prop_pcdata ],
    doc_operator	=> [ info,  'operator',	1, \&_prop_pcdata ],
    doc_category	=> [ info,  'category',	1, \&_prop_pcdata ],
    doc_keywords	=> [ info,  'keywords',	1, \&_prop_pcdata ],
    doc_summary	=> [ info,  'doccomm',	1, \&_prop_pcdata ],
    doc_comment	=> [ text,  '*\comment',	1, \&_prop_pcdata ],
    doc_base_href	=> [ info,  'hlinkbase', 	1, \&_prop_pcdata ],
    doc_version	=> [ info,  'version',	0, \&_prop_raw  ],
    doc_time_created	=> [ creatim ],

    doc_from_text	=> [ text,  fromtext,    0, \&_prop_on ],
    doc_make_backup	=> [ text,  makebackup,  0, \&_prop_on ],
    doc_rtf_def	=> [ text,  defformat,   0, \&_prop_on ],

    # --- Page sizes, margins, etc.
    doc_page_width	=> [ text,  paperw,	0, \&_prop_twips ],
    doc_page_height	=> [ text,  paperh,	0, \&_prop_twips ],
    doc_landscape	=> [ text,  landscape,	0, \&_prop_on ],
    doc_facing	=> [ text,  facingp,	0, \&_prop_on ],
    doc_margin_left	=> [ text,  margl,		0,  \&_prop_twips ],
    doc_margin_right	=> [ text,  margr,		0, \&_prop_twips ],
    doc_margin_top	=> [ text,  margt,		0, \&_prop_twips ],
    doc_margin_bottom => [ text,  margb, 	0, \&_prop_twips ],
    doc_margin_mirror=> [ text,  margmirror, 	0, \&_prop_on ],
    doc_gutter	=> [ text,  gutter, 	0, \&_prop_twips ],

    # --- Hyphenation
    doc_hyphen_auto	=> [ text,  'hyphauto', 0,  \&_prop_onoff ],
    doc_hyphen_caps	=> [ text,  'hyphcaps', 0,  \&_prop_onoff ],

    # --- Views
    doc_view_scale	=> [ text,  viewscale,   0, \&_prop_raw  ],
    doc_view_zoom	=> [ text, { none=>'viewzk0', 'full-page'=>'viewzk1',
      'best-fit'=>'viewzk1' },  0, \&_prop_decode ],
    doc_view_caption	=> [ text,  windowcaption, 1, , \&_prop_pcdata ],

    # --- Widow/orphan controls
    doc_widow_cntrl	=> [ text,  widowctrl,   0, \&_prop_on ],

    # --- Tabs
    tabs_default	=> [ text,  'deftab', 	0, \&_prop_twips ],

);

%PROPERTIES = (

    # --- New section, paragraph, line
    sec		=> [ text, 'sect', 	0, \&_prop_on ],
    par		=> [ text, 'par', 	0, \&_prop_on ],
    line		=> [ text, 'line', 	0, \&_prop_on ],
    line_soft		=> [ text, 'softline', 0, \&_prop_on ],

    # --- Sections....
    sec_brk		=> [ text, { none=>'sbknone', column=>'sbkcol',
      page=>'sbkpage', even=>'sbkeven', odd=>'sbkodd'}, 0, \&_prop_decode ],

    # --- Columns
    col		=> [ text,  'colulmn',  	0, \&_prop_on ],
    col_soft		=> [ text,  'softcol',  	0, \&_prop_on ],
    col_num		=> [ text,  'cols',  	0, \&_prop_raw ],
    col_space		=> [ text,  'colsx', 	0, \&_prop_twips ],
    col_select	=> [ text,  'colno', 	0, \&_prop_raw ],
    col_padding_right => [ text, 'colsr', 	0, \&_prop_twips ],
    col_width 	=> [ text,  'colw',		0, \&_prop_twips ],
    col_line		=> [ text,  'linebetcol',	0, \&_prop_on ],

    page_brk		=> [ text,  'page', 		0, \&_prop_on ],
    page_softbrk	=> [ text,  'softpage',	0, \&_prop_on ],

    # --- Forms....
    sec_unlock	=> [ text, 'sectunlocked', 	0, \&_prop_on ],

    # --- Footsnotes, endnotes stuff
    sec_endnotes_here => [ text, 'endnhere',	0, \&_prop_on ],

    # --- Alignment
    par_align		=> [ text, { left=>'ql', right=>'qr', center=>'qc', justify=>'qj' },  0, \&_prop_decode ],
    sec_vert_align	=> [ text, { top=>vertalt, bottom=>vertalb, center=>vertalc },  0, \&_prop_decode ],

    # --- Indentation
    par_indent_first	=> [ text,  'fi', 		0, \&_prop_twips ],
    par_indent_left	=> [ text,  'li', 		0, \&_prop_twips ],
    par_indent_right	=> [ text,  'ri', 		0, \&_prop_twips ],
    par_outline_level => [ text, 'outlinelevel', 0, \&_prop_raw ],

    # --- Style
    style		=> [ text,  's', 		0, \&_prop_style ],
    style_default	=> [ text, { character=>'plain', paragraph=>'pard', section=>'secd' },  0, \&_prop_decode ],

    # --- Paragraph spacing
    par_space_before	=> [ text,  'sb', 		0,  \&_prop_twips ],
    par_space_after	=> [ text,  'sa',		0,  \&_prop_twips  ],
    par_space_lines	=> [ text,  'sl',		0,  \&_prop_raw  ],
    par_space_lines_mult => [ text,  'slmult',	0,  \&_prop_raw  ],

    # --- Character formatting
    bold		=> [ text,  'b',		0,  \&_prop_onoff ],
    italic		=> [ text,  'i',		0,  \&_prop_onoff ],
    caps		=> [ text,  'caps',		0,  \&_prop_onoff ],
    caps_small	=> [ text,  'scaps',		0,  \&_prop_onoff ],
    underline		=> [ text, { off=>'ul0', continuous=>'ul', dotted=>'uld', dash=>'uldash', 'dot-dash'=>'uldashd', 'dot-dot-dash'=>'uldashdd', double=>'ulb', none=>'ulnone', thick=>'ulth', word=>'ulw', wave=>'ulwave' },  0, \&_prop_decode ],
    hidden		=> [ text,  'v',		0,  \&_prop_onoff ],

    # --- Colors
    color_foreground => [ text,  'cf',		0, \&_prop_raw ],
    color_background => [ text,  'cb',		0, \&_prop_raw ],
    highlight		 => [ text, 'highlight',	0, \&_prop_raw ],

    # --- Fonts
    font		=> [ text,  'f', 		0, \&_prop_raw ],
    font_size		=> [ text,  'fs',		0, \&_prop_halfpts ],
    font_scale	=> [ text,  'charscalex', 	0,  \&_prop_raw  ],

    # --- Page sizes, margins, etc.
    sec_page_width	=> [ text,  pgwsxn,		0, \&_prop_twips ],
    sec_page_height	=> [ text,  pghsxn,		0, \&_prop_twips ],
    sec_landscape	=> [ text,  lndscpsxn,	0, \&_prop_on ],
    sec_margin_left	=> [ text,  marglsxn,	0, \&_prop_twips ],
    sec_margin_right	=> [ text,  margrsxn,	0, \&_prop_twips ],
    sec_margin_top	=> [ text,  margtsxn,	0, \&_prop_twips ],
    sec_margin_bottom => [ text,  margbsxn,	0, \&_prop_twips ],
    sec_margin_mirror=> [ text,  margmirsxn, 	0, \&_prop_on ],
    sec_gutter	=> [ text,  guttersxn, 	0, \&_prop_twips ],

    sec_title_pg 	=> [ text,  titlepg, 	0, \&_prop_on ],
    sec_header_margin => [ text, headery, 	0, \&_prop_twips ],
    sec_footer_margin => [ text, footery, 	0, \&_prop_twips ],

    # --- Hyphenation
    par_hyphen	=> [ text,  'hyphpar', 0,  \&_prop_onoff ],

    # --- Widow/orphan controls
    par_widow_cntrl	=> [ text, { 0=>nowidctlpar, 1=>widctlpar },  0, \&_prop_decode ],
    par_intact	=> [ text,  keep,   0, \&_prop_on ],
    par_keep_next	=> [ text,  keepn,   0, \&_prop_on ],

    par_pgbrk_before	=> [ text,  pagebb,   0, \&_prop_on ],

    # --- Page numbering
    pg_num_start 	=> [ text,    pgnstart,    0, \&_prop_raw ],
    pg_num_cont	=> [ text,    pgncont,     0, \&_prop_on ],
    pg_num_restart 	=> [ text,    pgnrestart,  0, \&_prop_on ],

    # --- Character set
    doc_charset	=> [ Charset ]
);

sub set_properties
{
    my $self = shift;

    my $table = shift,
       $settings = shift,
       $destination = shift,
       $property, $value,
       $where, $what, $arg, $default;

    foreach $property (keys %{$settings}) {   
        if (defined(${$table}{$property}))
        {
            ($where, $what, $group, $default, $arg) = @{${$table}{$property}};

            if (defined($destination))
            {
                carp "\`$property\' is a document property",
                    if ($where ne "text");
                $where = $destination;
            } else {
                $where = $self->{$where}, if (defined($what));
            }

            if (defined($what))
            {
                $value = ${$settings}{$property};
                $what = $self->$default($what, $value, $arg);

                if (defined($what))
                {
                    $self->add_raw ($where, "\\".$what ), if (!$group);
                    $self->add_raw ($where, [ "\\".$what ] ), if ($group);
                }                
            } else {
                $self->{$where} = ${$settings}{$property};
            }

        } else {
            carp "Don\'t know how to handle property: \`$property\'";
        }
    }
}

sub initialize
{
    my $self = shift;
    $self->{Charset} 	= "ansi";	# Character Set

    $self->{DefaultFont} = "";	# Default Font

    $self->{fonttbl} 	= [];	# font tables
    $self->{fontCnt}	= 0;		# count of fonts in table

    $self->{colortbl} 	= [];	# color tables
    $self->{colorCnt}	= 0;	# count of colors in table

    $self->{styleCnt}	= 0;	# count of styles defined

    $self->{text} 		= [];	# root of Document Area

    $self->{info}		= $self->add_group();
    $self->{creatim} 	= time();
}

sub import {
    my $self = shift;
    $self->set_properties (\%DOCINFO, @_);
}

sub new
{
    my $this = shift;
    my $class = ref($this) || $this;
    my $self = {};
    bless $self, $class;
    $self->initialize();
    $self->import(@_);
    return $self;
}

sub escape_text
{
    local ($_) = shift;
    s/([\\\{\}])/\\$1/g;




    s/[\r]//g;

    s/\n{2,2}/\\par /g;
    s/\n/\\line /g;
    s/\t/\\tab /g;
    return $_;
}

sub emit_group {
    local ($el, $data);

    unless (@_) {
        return undef;
    }

    $data = "\{";

    foreach $el (@_)
    {
        if (ref($el) eq ARRAY) {
            $data .= emit_group(@$el);
        } else {
            if (($el !~ m/^[\\\;\{\}]/) and (substr($data, length($data)-1) !~ m/[\}\{\s]/)) {
                $data .= " ";
            }
            $data .= $el;
        }
    }
    $data .= "\}";
    return $data;

}


%FONTCLASSES = (
    swiss	=> swiss,
    'sans-serif' => swiss,
    roman	=> roman,
    serif	=> roman,
    modern	=> modern,
    monospace	=> modern,
    script	=> script,
    decor	=> decor,
    fantasy	=> decor,
    tech	=> tech,
    symbol	=> tech,
    bidi	=> bidi
);
%FONTPITCH = (
    default 	=> 0,
    fixed   	=> 1,
    variable 	=> 2
);
sub add_font
{
    local ($_);
    my $self = shift;

    my $name = shift;
    my $attributes = shift;

    my $class = $FONTCLASSES{${$attributes}{family}};

    unless ($self->{fontCnt}) {
        $self->add_raw ($self->{fonttbl}, '\fonttbl');
        $self->{DefaultFont} = "f".$self->{fontCnt};   # the first font defined is default
    }

    my @fattr = ('\f'.$self->{fontCnt}, '\f'.$class);

    if (defined(my $pitch = ${$attributes}{pitch}))
    {
        push @fattr, '\fprq'. ($FONTPITCH{ $pitch }
            or carp "Don\'t know how to handle \`pitch => $pitch\'" ) ;
    }

    if (defined(my $actual = ${$attributes}{name})) # non-tagged name (is this correct?)
    {
        push @fattr, ('\*\fname '. $actual);
    }

    push @fattr, $name;

    my @alternates = @{${$attributes}{alternates}};
    if (@alternates) {
        while ($_ = shift @alternates) {
            push @fattr, [ '\*\falt '.$_ ];
        }
    }

    $self->add_raw ($self->{fonttbl}, [ @fattr, ';'] );

    if (${$attributes}{default}) {
        carp "Default font has already been defined.",
            if ($self->{DefaultFont} ne "f0");
        $self->{DefaultFont} = $self->{fontCnt};
    }

    return $self->{fontCnt}++;
}


sub decode_stylename
{
    my $name = shift;
    my $current = shift || '\s0';

    $current =~ m/^\\[cd]?s(\d+)/;
    my ($next, $last) = ($1+1, $1-1);
    $last = 222, if ($last<0);
   
    return '\s222', if ($name eq "none");
    return '\s0', if ($name eq "default");
    return $current, if ($name eq "self");
    return '\s'.$next, if ($name eq "next");
    return '\s'.$last, if ($name eq "last");
    return $name;
}

%STYLETYPES = (
    character => '\*\cs',
    paragraph => '\s',
    section => '\ds'
);

sub add_style
{
    my $self = shift;
    my ($name, $formatting, $attributes) = @_;

    $type = ${$attributes}{type} || "paragraph";
    my $code = $STYLETYPES{$type};
    unless (defined($code)) {
        carp "Don\'t know how to handle a \`$type\' style";
    }

    my $style;
    if (${$attributes}{default}) {
        carp "Default style\'s type must be \`paragraph\'", if ($type ne "paragraph");       
        $code = "\\s0";
        $style = $code;
        $self->{$style} = [ ];
    } else {
        $code .= ++$self->{styleCnt};
        ($style = $code) =~ s/^\\\*//;
        $self->{$style} = [ $code ];
    }

    my $aux = [];

    $self->set_properties( \%PROPERTIES, $formatting, $aux);
    $self->{styles}->{$style} = $aux;

    push @{$self->{$style}}, @{$aux};

    my $sbasedon = ${$attributes}{basedon} || "none",
       $snext    = ${$attributes}{next}    || "self";

    $sbasedon = decode_stylename($sbasedon, $style);
    $snext    = decode_stylename($snext, $style);

    $sbasedon =~ s/^\\[dc]?s//; $snext =~ s/^\\[dc]?s//;

    push @{$self->{$style}}, ('\sbasedon'.$sbasedon), if (defined(${$attributes}{basedon}));
    push @{$self->{$style}}, ('\snext'.$snext), if (defined(${$attributes}{next}));

    push @{$self->{$style}}, ('\shidden'), if (${$attributes}{hidden});
    push @{$self->{$style}}, ('\sautoupd'), if (${$attributes}{autoupdate});

    if ($type eq "character") {
        if (${$attributes}{additive}) {
            push @{$self->{$style}}, '\additive';
        } else {
            unshift (@{$aux}, ('\plain'));
        }
    } else {
        unshift @{$aux}, ('\pard', '\plain');
    }

    $name =~ s/([\\\{\}])/\\$1/g;
    push @{$self->{$style}}, $name.";";

    return $style;
}

%COLORNAMES = (
    black	=> [0, 0, 0],
    blue	=> [0, 0, 255],
    aqua	=> [0, 255, 255],
    lime	=> [0, 255, 0],
    fuscia	=> [255, 0, 255],
    red		=> [255, 0, 0],
    yellow	=> [255, 255, 0],
    white	=> [255, 255, 255],
    navy	=> [0, 0, 128],
    teal	=> [0, 128, 128],
    green	=> [0, 128, 0],
    purple => [128, 0, 128],
    maroon	=> [128, 0, 0],
    olive => [128, 128, 0],
    gray	=> [128, 128, 128],
    silver	=> [192, 192, 192],
);

sub parse_value
{
    local ($_) = shift;
    $_ = $1 * 2.55, if (m/\-?(\d+(\.\d*)?)\s*\%$/);
    return POSIX::ceil($_);
}

sub add_color
{
    my $self = shift;
    my $attributes = shift;
    my ($red, $grn, $blu);

    if (defined(${$attributes}{name})) {
        my $name = ${$attributes}{name};
        ($red, $grn, $blu) = @{$COLORNAMES{$name}};
        carp "Unrecognized color name \`$name\'", 
          unless (defined($COLORNAMES{$name}));
    } else {
        $red = parse_value(${$attributes}{red});
        $grn = parse_value(${$attributes}{green});
        $blu = parse_value(${$attributes}{blue});
    }

    if (${$attributes}{gray}) {
        ($red, $grn, $blu) = (255, 255, 255), unless ($red+$grn+$blu);
        
        $red = POSIX::ceil(parse_value(${$attributes}{gray}) / 255 * $red);
        $grn = POSIX::ceil(parse_value(${$attributes}{gray}) / 255 * $grn);
        $blu = POSIX::ceil(parse_value(${$attributes}{gray}) / 255 * $blu);
    }

    unless ($self->{colorCnt}++) {
        $self->add_raw ($self->{colortbl}, '\colortbl;');
    }

    foreach ($red, $grn, $blu) {
        carp "Invalid color value: $_.", if ($_<0) or ($_>255);
    }

    $self->add_raw ($self->{colortbl}, ("\\red$red", "\\green$grn", "\\blue$blu;") );

    return $self->{colorCnt};
}

sub add_group {
    my $self = shift;
    my $section = shift || $self->{text};
    my $group = [ ];
    $self->add_raw ($section, $group);
    return $group;
}

sub root {
    my $self = shift;
    return $self->{text};
}

sub add_raw # add a raw value to a section
{
    my $self = shift;
    my $section = shift;

    push @{$section}, @_;
}

sub add_text {
    my $self = shift;
    my $group = shift || $self->root();
    my $arg, $rarg;

    while ($arg = shift) {
        $rarg = ref($arg);
        if ($rarg eq HASH)
        {
            $self->set_properties (\%PROPERTIES, $arg, $group);
        }
        elsif ($rarg eq ARRAY)
        {
            my $subgroup = $self->add_group($group);
            $self->add_text ($subgroup, @{$arg} );
        }
        elsif ($rarg eq SCALAR)
        {
            $self->add_text (${$arg});
        }
        else
        {
            $self->add_raw ($group, escape_text($arg));
        }
    }


}

sub rtf
{
    my $self = shift;

    # --- Begin assembling the document with component groups
    my $DOCUMENT = [];

    # --- Create the RTF header
    $self->add_raw (
        $DOCUMENT,
        "\\rtf",
        "\\".$self->{Charset}
    );

    if ($self->{DefaultFont} ne "")
    {
        $self->add_raw ($DOCUMENT, '\deff'.$self->{DefaultFont});
    }
    else
    {
        carp "Waning: no default font has been specified!";
    }

    # 
    my $styletable = [];

    $self->add_raw (
        $DOCUMENT,
        $self->{fonttbl},
        $self->{colortbl},
        $styletable,
        @{$self->{text}}
    );

    # ----- Build style sheets and insert into the Style Table
    if (($self->{styleCnt}) or (defined($self->{"\\s0"}))) {

        push @{$styletable}, '\stylesheet';
        my $i = 0, $style;
        while ($i<=$self->{styleCnt}) {
            $style = "\\s".$i;
            $style = "\\ds".$i, unless (defined($self->{$style}));
            $style = "\\cs".$i, unless (defined($self->{$style}));
            if (defined($self->{$style})) {
                push @{$styletable}, [ @{$self->{$style}} ];
            }
            ++$i;
        }
    }

    # ----- Insert creation time in Information Group
    if ($self->{creatim})
    {
        my ($ss, $mn, $hr, $dd, $mm, $yy) = localtime($self->{creatim});
        $yy+=1900; $mm++;
        $self->add_raw(
            $self->{info}, [ 
            "\\creatim",
            "\\yr$yy",
            "\\mo$mm",
            "\\dy$dd",
            "\\hr$hr",
            "\\min$mn",
            "\\sec$ss" ]
         );
    };

    if (@{$self->{info}}) {
        unshift @{$self->{info}}, '\info';
    } else {
        $self->{info} = [];
    }

    return emit_group @{$DOCUMENT};
}

1;

__END__

=head1 NAME

RTF::Document - Perl extension for generating Rich Text (RTF) Files 

=head1 DESCRIPTION

RTF::Document is a module for generating Rich Text Format (RTF) documents
that can be used by most text converters and word processors.

The interface is not yet documented, although the example below will
demonstrate how to use this module.

For a listing of properties, consult the %PROPERTIES hash in the source
code.

=head1 REQUIRED MODULES

    Carp
    POSIX
    Units::Type 0.32

Units::Type is part of the Units package.

=head1 EXAMPLE

    use RTF::Document;

    # Document properties

    $rtf = new RTF::Document(
      {
        doc_page_width => '8.5in',
        doc_page_height => '11in'
      }
    );

    # Font definitions

    $fAvantGarde = $rtf->add_font ("AvantGarde", 
       { family=>swiss,
         default=>1
       } );
    $fCourier = $rtf->add_font ("Courier",
      { family=>monospace, pitch=>fixed, 
        alternates=>["Courier New", "American Typewriter"] 
      } );

    # Color definitions

    $cRed   = $rtf->add_color ( { red=>255 } );
    $cGreen = $rtf->add_color ( { green=>128 } );
    $cCustm = $rtf->add_color ( { red=>0x66, blue=>0x33, green=>0x33 } );

    $cBlack = $rtf->add_color ( { name=>'black' } );
    $cWhite = $rtf->add_color ( { gray=>'100%' } );

    $cNavy = $rtf->add_color ( { blue=>'100%', gray=>'50%' } );

    # style definitions

    $sNormal = $rtf->add_style( "Normal",
      { font=>$fAvantGarde, font_size=>'12pt',
        color_foreground=>$cBlack },
      { type=>paragraph, default=>1 }
    );

    $sGreen = $rtf->add_style( "Green",
      { color_foreground=>$cGreen },
      { type=>character, additive=>1 }
    );

    # Mix any combo of properties and text...

    $rtf->add_text( $rtf->root(),
       "Default text\n\n",

       { bold=>1, underline=>dash },
       "Bold/Underlined Text\n\n",

       { font_size=>'20pt', font=>$fCourier,
         color_foreground=>$cRed },
       "Bigger, Red and Monospaced.\n\n",

       { style_default=>paragraph, style_default=>character },

       "This is ",
       [ { style=>$sGreen }, "green" ],
       " styled.\n\n"

    );

    open FILE, ">MyFile.rtf";
    binmode FILE;
    print FILE $rtf->rtf();
    close FILE;

=head1 KNOWN ISSUES

This module should be considered in the "alpha" stage. Use at your own risk.

There are no default document or style properties produced by this module,
with the exception of the character set. If you want to make sure that a
specific font, color, or style is available, you must specify it. (You
may be able to rely on default properties documented in the RTF specification,
but you do so at the risk that an RTF viewer will assume different defaults.)

This module does not insert newlines anywhere in the text, even though some
RTF writers break lines before they exceed 225 characters.  This may or may
not be an issue with some reader software.

Unknown text or document properties will return a warning. Attempting to
define a "global" document property (for example, defining the paper size)
within the text will also produce a warning but the code will be emitted
in place anyway. This "feature" may change in a future version.

Unknown font or style properties will generally be ignored without warning.
Inappropriate properties for a specific font or style are also ignored.

Potentially invalid names for fonts and styles are ignored. (Hint: don't
use tabs, newlines, backslashes, brackets, or other control characters in
these.)

Colors can be created by naming them, for instance, 

    $cBlue = $rtf->add_color( { name => blue } );

Note that the names and associated RGB codes come from the W3C's HTML4
specification. Microsoft uses the same RGB color values for defaults in
word, although they have different names. (The only conflict is with
the definition of "green".)  Future versions will incorporate separate
module which recognizes common names and returns appropriate RGB
values.

Fonts, Colors and Styles are referenced in text and style properties using
the returned values when they are added, and I<not> by names associated
with them.  This is intentional, since it makes the interface more
object-oriented.

Once a Font, Color or Style is added, it cannot be changed. No checking
for redundant entries is done.

Generally, it is not possible to reference a not-yet-created Style with the
next or basedon attributes. However, you can use the constances "last",
"self" or "next" to reference the last style added, the current style
being added, or the next style that will be added, respectively.

Properties are I<write-only> (global properties should be considered
I<write-once> as well).

Specifying properties in a particular order within a group does not
guarantee that they will be emitted in that order. If order matters,
specify them separetly. For instance,

    $rtf->add_text($rtf->root, { style_default=>character, bold=>1 } );

should be (if you want to ensure character styles are reset before setting
bold text):

    $rtf->add_text($rtf->root, { style_default=>character }, { bold=>1 } );

=head2 Unimplemented Features

A rather large number of features and control words are not handled in this
version. Among the major features:

=over

=item Annotations and Comments

=item Bookmarks

=item Bullets and Line Numbering

=item Character Sets and Internationalization

Non-"ANSI" character sets (i.e., Macintosh) and Unicode character
sets are not supported (at least not intentionally). There is no
support for Asian character sets in this version of the module.

Unicode character escapes are not implemented.

Language codes (defining a default language, or a language for a
group of characters) are not implemented.

Bi-directional and text-flow controls are not implemented.

=item Embedded Images and OLE Objects

=item File Tables

=item Footnotes and Endnotes

=item Forms

=item Headers and Footers

=item Hyphenation Control

=item Lists and List Tables

=item Page Numbering

Minimal definition, untested.

=item Printer Bin Controls

=item Revision Tables

=item Special Characters and Document Variables

Most special characters not not implemented, with the exception of tabs. Double
newline characters are converted to a new paragraph control, and single newlines
are converted to a new line control.

=item Tabs

=item Tables and Frames

=back

=head1 SEE ALSO

Microsoft Technical Support and Application Note, "Rich Text Format (RTF)
Specification and Sample Reader Program", Version 1.5.

I<Units::Type>.

=head1 AUTHOR

Robert Rothenberg <wlkngowl@unix.asb.com>

=head1 LICENSE

Copyright (c) 1999 Robert Rothenberg. All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.