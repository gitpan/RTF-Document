package RTF::Document;
require 5.005;
require Exporter;

use vars qw(
    $VERSION
    %DOCINFO %PROPERTIES
    %FONTCLASSES %FONTPITCH %COLORNAMES %STYLETYPES %NUMSTYLES
);
$VERSION = "0.64";

@ISA = qw(Exporter);
@EXPORT = qw();
@EXPORT_OK = qw();

use Carp;
use POSIX qw(floor ceil);
use Convert::Units::Type 0.33;

%NUMSTYLES = (
    '1' => '\pndec',
    'a' => '\pnlcltr',
    'i' => '\pnlcrm',
    'A' => '\pnucltr',
    'I' => '\pnucrm',
    '1st' => '\pnord'
);

sub _prop_list
{
    my ($self, $code, $properties) = @_;
    my ($result, $level, $style);

    if ($properties eq "off") {
        return '\pard';
    }

    $result = $self->new_group( '\*', '\pn' );

    ${$properties}{level} = ${$properties}{style}, if (${$properties}{style} eq "bullet");

    if (${$properties}{level}) {
        $level = ${$properties}{level};
        $level = "blt", if ($level eq "bullet");
        if ((($level<1) or ($level>11)) and ($level ne "blt"))
        {
            carp "List level \`$level\' is out of range";
            $level = 'body';
        }
    } else {
        $level = 'body';
    }

    $self->add_raw ($result, '\pnlvl'.$level);

    if ($level eq "body")  {
        $style = $NUMSTYLES{${$properties}{style}} || '\pndec';
        $self->add_raw ($result, $style);
    }

    if (defined(${$properties}{font}))
    {
       $self->add_raw ($result, '\pnf'.${$properties}{font});
    }

    if (defined(${$properties}{color}))
    {
       $self->add_raw ($result, '\pncf'.${$properties}{color});
    }

    if (defined(${$properties}{before}))
    {
       my $group = $self->add_group($result);
       $self->add_raw ($group, '\pntxtb '.escape_simple(${$properties}{before}) );
    }

    if (defined(${$properties}{after}))
    {
       my $group = $self->add_group($result);
       $self->add_raw ($group, '\pntxta '.escape_simple(${$properties}{after}) );
    }

    if (${$properties}{across})
    {
       $self->add_raw ($result, '\pnacross');
    }

    if (defined(${$properties}{indent}))
    {
       $self->add_raw ($result, '\pnindent'.POSIX::floor(
         Convert::Units::Type::convert(${$properties}{indent}, "twips")
       ));
    }

    if (defined(${$properties}{space}))
    {
       $self->add_raw ($result, '\pnsp'.POSIX::floor(
         Convert::Units::Type::convert(${$properties}{space}, "twips")
       ));
    }

    if (${$properties}{hang})
    {
       $self->add_raw ($result, '\pnhang');
    }

    if (defined(${$properties}{start}))
    {
       $self->add_raw ($result, '\pnstart'.${$properties}{start});
    }


    return ($result);
}

# $arg is a key to RTF control in hash value
sub _prop_decode
{
    my ($self, $hash, $arg) = @_;
    my $result = ${$hash}{$arg};

    unless (defined($result)) {
        carp "Don\'t know how to handle value \`$arg\'";
    }

    return ("\\".$result);
}

sub _prop_style {
    my ($self, $code, $arg) = @_;
    $code = decode_stylename($arg, '\s222');
    my $formatting, $style_properties;

    if (defined($code)) {
        $formatting = $self->new_group();
        %{$style_properties} = %{$self->{styles}->{$code}};

        if (${$style_properties}{secd}) {
            $self->add_raw($formatting, '\secd');
            delete ${$style_properties}{secd};
        }
        if (${$style_properties}{pard}) {
            $self->add_raw($formatting, '\pard');
            delete ${$style_properties}{pard};
        }
        if (${$style_properties}{plain}) {
            $self->add_raw($formatting, '\plain');
            delete ${$style_properties}{plain};
        }

        $self->set_properties( \%PROPERTIES, $style_properties, $formatting);
        unless (@{$formatting}) {
            carp "Style \`$arg\' is not defined";
            $code = decode_stylename("none");
        }
    }
    return ($code, @{$formatting} );
}

# $arg is a unit of type (points, picas, inches) converted to twips
sub _prop_twips {
    my ($self, $code, $arg) = @_;
    return ("\\".$code.POSIX::floor(Convert::Units::Type::convert($arg, "twips")));
}

# $arg is a unit of type (points, picas, inches) converted to half-points
sub _prop_halfpts {
    my ($self, $code, $arg) = @_;
    return ("\\".$code.POSIX::floor(Convert::Units::Type::convert($arg, "half-points")));
}

# $arg is a string (which may need to be escaped)
sub _prop_pcdata {
    my ($self, $code, $arg) = @_;
    $arg =~ s/([\\\{\}])/\\$1/g;
    return ("\\".$code, escape_simple($arg));
}

# $arg is a raw value
sub _prop_raw {
    my ($self, $code, $arg) = @_;
    return ("\\".$code.$arg);
}

# $arg is a an on/off indicator (0 = off, NZ = on)
sub _prop_onoff {
    my ($self, $code, $arg) = @_;
    if ($arg)
    {
        return ("\\".$code);
    }
    else
    {
        return ("\\".$code."0");
    }
}

# $arg is a an emit/don't emit indicator (0 = don't emit control, NZ = emit)
sub _prop_on {
    my ($self, $code, $arg) = @_;
    if ($arg)
    {
        return ("\\".$code);
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
    'doc_title'		=> [ 'info',  'title', 	1, \&_prop_pcdata ],
    'doc_author'		=> [ 'info',  'author',	1, \&_prop_pcdata ],
    'doc_subject'		=> [ 'info',  'subject',	1, \&_prop_pcdata ],
    'doc_manager'		=> [ 'info',  'manager',	1, \&_prop_pcdata ],
    'doc_company'		=> [ 'info',  'company',	1, \&_prop_pcdata ],
    'doc_operator'		=> [ 'info',  'operator',	1, \&_prop_pcdata ],
    'doc_category'		=> [ 'info',  'category',	1, \&_prop_pcdata ],
    'doc_keywords'		=> [ 'info',  'keywords',	1, \&_prop_pcdata ],
    'doc_summary'		=> [ 'info',  'doccomm',	1, \&_prop_pcdata ],
    'doc_comment'		=> [ 'text',  '*\comment',	1, \&_prop_pcdata ],
    'doc_base_href'		=> [ 'info',  'hlinkbase', 	1, \&_prop_pcdata ],
    'doc_version'		=> [ 'info',  'version',	0, \&_prop_raw  ],
    'doc_time_created'	=> [ 'creatim' ],

    'doc_from_text'		=> [ 'text',  'fromtext',    0, \&_prop_on ],
    'doc_make_backup'	=> [ 'text',  'makebackup',  0, \&_prop_on ],
    'doc_rtf_def'		=> [ 'text',  'defformat',   0, \&_prop_on ],

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
    doc_hyphen_auto	=> [ 'text', 'hyphauto', 0,  \&_prop_onoff ],
    doc_hyphen_caps	=> [ 'text', 'hyphcaps', 0,  \&_prop_onoff ],
    doc_hyphen_lines	=> [ 'text', 'hyphconsec', 0,  \&_prop_onoff ],
    doc_hyphen_zone	=> [ 'text', 'hyphhotz', 0,  \&_prop_twips ],

    # --- Views
    doc_view_scale	=> [ text,  viewscale,   0, \&_prop_raw  ],
    doc_view_zoom	=> [ text, { none=>'viewzk0', 'full-page'=>'viewzk1',
      'best-fit'=>'viewzk1' },  0, \&_prop_decode ],
    doc_view_caption	=> [ text, windowcaption, 1, , \&_prop_pcdata ],
    'doc_view_mode'	=> [ 'text', { 'none'=>'viewkind0', 'layout'=>'viewkind1',
      'outline'=>'viewkind2', 'master'=>'viewkind3',




      'normal'=>'viewkind4', 'online'=>'viewkind5'}, 0, \&_prop_decode ],

    # --- Character set
    'doc_charset'		=> [ 'charset' ],

    # --- Widow/orphan controls
    doc_widow_cntrl	=> [ text,  widowctrl,   0, \&_prop_on ],

    # --- Tabs
    tabs_default	=> [ 'text',  'deftab', 	0, \&_prop_twips ],

);

%PROPERTIES = (

    # --- New section, paragraph, line
    'sec'		=> [ 'text', 'sect', 	0, \&_prop_on ],
    'par'		=> [ 'text', 'par', 		0, \&_prop_on ],
    'line'		=> [ 'text', 'line', 	0, \&_prop_on ],
    'line_soft'	=> [ 'text', 'softline', 	0, \&_prop_on ],

    # --- Sections....
    'sec_brk'		=> [ 'text', { 'none'=>'sbknone', 'column'=>'sbkcol',
      'page'=>'sbkpage', 'even'=>'sbkeven', 'odd'=>'sbkodd'}, 0, \&_prop_decode ],

    # --- Columns
    col		=> [ text,  'colulmn',  	0, \&_prop_on ],
    col_soft		=> [ text,  'softcol',  	0, \&_prop_on ],
    col_num		=> [ text,  'cols',  	0, \&_prop_raw ],
    col_space		=> [ text,  'colsx', 	0, \&_prop_twips ],
    col_select	=> [ text,  'colno', 	0, \&_prop_raw ],
    col_padding_right => [ text, 'colsr', 	0, \&_prop_twips ],
    col_width 	=> [ text,  'colw',		0, \&_prop_twips ],
    col_line		=> [ text,  'linebetcol',	0, \&_prop_on ],

    'page_brk'	=> [ 'text', 'page', 	0, \&_prop_on ],
    'page_softbrk'	=> [ 'text', 'softpage',	0, \&_prop_on ],

    # --- Forms....
    'sec_unlock'	=> [ 'text', 'sectunlocked', 	0, \&_prop_on ],

    # --- Footsnotes, endnotes stuff
    'sec_endnotes_here' => [ 'text', 'endnhere',	0, \&_prop_on ],

    # --- Alignment
    'par_align'	=> [ 'text', { left=>'ql', right=>'qr', center=>'qc', justify=>'qj' },  0, \&_prop_decode ],
    'sec_vert_align'	=> [ 'text', { top=>vertalt, bottom=>vertalb, center=>vertalc },  0, \&_prop_decode ],

    # --- Indentation
    'par_indent_first'	=> [ 'text', 'fi', 	0, \&_prop_twips ],
    'par_indent_left'	=> [ 'text', 'li', 	0, \&_prop_twips ],
    'par_indent_right'	=> [ 'text', 'ri', 	0, \&_prop_twips ],
    'par_outline_level'	=> [ 'text', 'outlinelevel', 0, \&_prop_raw ],

    'par_number_text'	=> [ 'text', 'pntext', 1, \&_prop_pcdata ],
    'par_number'		=> [ 'text', 'pn', 0, \&_prop_list ],

    # --- Style
    'style'		=> [ 'text', 's', 		0, \&_prop_style ],
    'style_default'	=> [ 'text', { 'character'=>'plain', 'paragraph'=>'pard',
        'section'=>'secd', 'row'=>'trowd', 'cell'=>'tcelld' },  0, \&_prop_decode ],

    # --- Paragraph spacing
    'par_space_before'	=> [ 'text', 'sb',	0,  \&_prop_twips ],
    'par_space_after'	=> [ 'text', 'sa',	0,  \&_prop_twips  ],
    'par_space_lines'	=> [ 'text', 'sl',	0,  \&_prop_raw  ],
    'par_space_lines_mult'	=> [ 'text', 'slmult', 0,  \&_prop_raw  ],

    # --- Character formatting
    'bold'		=> [ 'text',  'b',		0,  \&_prop_onoff ],
    'italic'		=> [ 'text',  'i',		0,  \&_prop_onoff ],
    'caps'		=> [ 'text',  'caps',	0,  \&_prop_onoff ],
    'caps_small'	=> [ 'text',  'scaps',	0,  \&_prop_onoff ],
    'underline'	=> [ 'text', { 'off'=>'ul0', 'continuous'=>'ul', 'dotted'=>'uld',
        'dash'=>'uldash', 'dot-dash'=>'uldashd', 'dot-dot-dash'=>'uldashdd',
        'double'=>'ulb', 'none'=>'ulnone', 'thick'=>'ulth', 'word'=>'ulw',
        'wave'=>'ulwave' },  0, \&_prop_decode ],
    'hidden'			=> [ 'text', 'v',		0,  \&_prop_onoff ],

    # --- Colors
    'color_foreground' 	=> [ 'text', 'cf',		0, \&_prop_raw ],
    'color_background' 	=> [ 'text', 'cb',		0, \&_prop_raw ],
    'highlight'		=> [ 'text', 'highlight',	0, \&_prop_raw ],

    # --- Fonts
    'font'			=> [ 'text', 'f', 		0, \&_prop_raw ],
    'font_size'		=> [ 'text', 'fs',		0, \&_prop_halfpts ],
    'font_scale'		=> [ 'text', 'charscalex', 	0,  \&_prop_raw  ],

    # --- Page sizes, margins, etc.
    'sec_page_width'		=> [ 'text', 'pgwsxn',	0, \&_prop_twips ],
    'sec_page_height' 	=> [ 'text', 'pghsxn',	0, \&_prop_twips ],
    'sec_landscape'		=> [ 'text', 'lndscpsxn',	0, \&_prop_on ],
    'sec_margin_left' 	=> [ 'text', 'marglsxn',	0, \&_prop_twips ],
    'sec_margin_right' 	=> [ 'text', 'margrsxn',	0, \&_prop_twips ],
    'sec_margin_top'	 	=> [ 'text', 'margtsxn',	0, \&_prop_twips ],
    'sec_margin_bottom' 	=> [ 'text', 'margbsxn', 	0, \&_prop_twips ],
    'sec_margin_mirror' 	=> [ 'text', 'margmirsxn',	0, \&_prop_on ],
    'sec_gutter'		=> [ 'text', 'guttersxn', 	0, \&_prop_twips ],

    'sec_title_pg' 		=> [ 'text', 'titlepg', 	0, \&_prop_on ],
    'sec_header_margin' 	=> [ 'text', 'headery', 	0, \&_prop_twips ],
    'sec_footer_margin' 	=> [ 'text', 'footery', 	0, \&_prop_twips ],

    # --- Hyphenation
    'par_hyphen'		=> [ 'text', 'hyphpar', 	0,  \&_prop_onoff ],

    # --- Widow/orphan controls
    'par_widow_cntrl' 	=> [ text, { 0=>nowidctlpar, 1=>widctlpar }, 0, \&_prop_decode ],
    'par_intact'		=> [ 'text', 'keep',  	0, \&_prop_on ],
    'par_keep_next'		=> [ 'text', 'keepn',	0, \&_prop_on ],

    'par_pgbrk_before' 	=> [ 'text', 'pagebb',	0, \&_prop_on ],

    # --- Page numbering
    'pg_num_start' 		=> [ 'text', 'pgnstart',	0, \&_prop_raw ],
    'pg_num_cont'		=> [ 'text', 'pgncont',	0, \&_prop_on ],
    'pg_num_restart' 	=> [ 'text', 'pgnrestart',	0, \&_prop_on ],

    'sec_title_pg' 		=> [ 'text', 'titlepg', 	0, \&_prop_on ]
);

sub set_properties
{
    my $self = shift;

    my $table = shift,
       $settings = shift,
       $destination = shift;
    my ($property, $value, $where, $what, $arg, $default);

    local ($_);

    foreach $property (keys %{$settings}) {   
        if (defined(${$table}{$property}))
        {
            ($where, $what, $group, $default, $arg) = @{${$table}{$property}};

            if (defined($destination))
            {
                carp "\`$property\' is not a section, paragraph or character property",
                    if ($where ne "text");
                $where = $destination;
            } else {
                $where = $self->{$where}, if (defined($what));
            }

            if (defined($what))
            {
                $value = ${$settings}{$property};
                my @controls = $self->$default($what, $value, $arg);

                if (@controls)
                {
                    if ($group) {
                        my $subgroup = $self->add_group($where);
                        $self->add_raw ($subroup, @controls );
                    } else {
                        $self->add_raw ($where, @controls );
                    }
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
    $self->{charset} 	= "ansi";	# Character Set

    # --- Document Header
    $self->{DOCUMENT}	= $self->new_group( '\rtf', $self->{charset} );

    $self->{fonttbl}		= $self->add_group($self->{DOCUMENT});
    $self->{fontCnt}		= 0;

    $self->{colortbl}	= $self->add_group($self->{DOCUMENT});
    $self->{colorCnt}	= 0;	# count of colors in table

    $self->{styletbl} 	= $self->add_group($self->{DOCUMENT});
    $self->{styleCnt}	= 0;	# count of styles defined

    $self->{text} 		= $self->add_group($self->{DOCUMENT});

    $self->{info} 		= $self->add_group();
    $self->add_raw		( $self->{info}, '\info' );
    $self->{creatim} 	= time();
}

sub import {
    my $self = shift;
    $self->set_properties (\%DOCINFO, @_);

    $self->splice_raw ($self->{DOCUMENT}, 1, 1, "\\".$self->{charset});

    # --- Insert creation time in Information Group
    if ($self->{creatim})
    {
        my ($ss, $mn, $hr, $dd, $mm, $yy) = localtime($self->{creatim});
        $yy+=1900; $mm++;

        my $creatim = $self->add_group($self->{info});

        $self->add_raw( $creatim,  '\creatim',
            "\\yr$yy", "\\mo$mm", "\\dy$dd", "\\hr$hr", "\\min$mn", "\\sec$ss"
        );
        $self->{creatim} = 0;
    };
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
    'swiss'	=> 'swiss',
    'sans-serif' => 'swiss',
    'roman'	=> 'roman',
    'serif'	=> 'roman',
    'modern'	=> 'modern',
    'monospace' => 'modern',
    'script'	=> 'script',
    'decor'	=> 'decor',
    'fantasy'	=> 'decor',
    'tech'	=> 'tech',
    'symbol'	=> 'tech',
    'bidi'	=> 'bidi'
);
%FONTPITCH = (
    'default' => 0,
    'fixed'  	=> 1,
    'variable' => 2
);
sub add_font
{
    local ($_);
    my $self = shift;

    my $name = shift,
       $attributes = shift;

    my $class = $FONTCLASSES{${$attributes}{family}};

    unless (defined($class)) {
        $class = "nil";
        carp "Unknown font family \`${$attributes}{family}\'";
    }

    unless ($self->{fontCnt}) {
        $self->add_raw ($self->{fonttbl}, '\fonttbl');
        $self->splice_raw ($self->{DOCUMENT}, 2, 0, "\\deff".$self->{fontCnt});
    }

    my $fattr = $self->add_group($self->{fonttbl});

    $self->add_raw ($fattr, ('\f'.$self->{fontCnt}, '\f'.$class) );

    if (defined(my $pitch = ${$attributes}{pitch}))
    {
        $self->add_raw ($fattr, '\fprq'. ($FONTPITCH{ $pitch }
            or carp "Don\'t know how to handle \`pitch => $pitch\'" )
        );
    }

    if (defined(my $actual = ${$attributes}{name})) # non-tagged name (is this correct?)
    {
        $self->add_raw ($fattr, ['\*\fname '.escape_simple($actual) ] );
    }

    $self->add_raw ($fattr, escape_simple($name) );

    my @alternates = @{${$attributes}{alternates}};
    if (@alternates) {
        while ($_ = shift @alternates) {
            $self->add_raw ($fattr, [ '\*\falt '.escape_simple($_) ] );
        }
    }

    $self->add_raw ($fattr, ';' );

    if (${$attributes}{default}) {
        carp "Default font redefined",
            if (@{$self->{DOCUMENT}}[2] ne "\\deff0");
            @{$self->{DOCUMENT}}[2] = "\\deff".$self->{fontCnt};
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
    'character' => '\*\cs',
    'paragraph' => '\s',
    'section' => '\ds'
);

sub add_style
{
    my $self = shift;
    my ($name, $formatting, $attributes) = @_;

    unless (@{$self->{styletbl}}) {
        $self->add_raw ( $self->{styletbl}, '\stylesheet');
    }

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
        $self->{$style} = $self->new_group();;
    } else {
        $code .= ++$self->{styleCnt};
        ($style = $code) =~ s/^\\\*//;
        $self->{$style} = $self->new_group( $code );
    }

    $self->set_properties( \%PROPERTIES, $formatting, $self->{$style} );

    carp "Warning: next attribute for style sheets is not used",
        if (defined(${$attributes}{next}));

    my $sbasedon = ${$attributes}{basedon} || "none",
       $snext    = ${$attributes}{next}    || "self";

    $sbasedon = decode_stylename($sbasedon, $style);
    $snext    = decode_stylename($snext, $style);

    # --- Inherit stylesheet from "basedon"
    if ($sbasedon ne '\s222') {
         %{$self->{styles}->{$style}} = %{$self->{styles}->{$sbasedon}};
    } else {
        $self->{styles}->{$style} = {};
    }

    foreach my $aux (keys %{$formatting}) {
        ${$self->{styles}->{$style}}{$aux} = ${$formatting}{$aux};
    }

    $sbasedon =~ s/^\\[dc]?s//; $snext =~ s/^\\[dc]?s//;

    push @{$self->{$style}}, ('\sbasedon'.$sbasedon), if (defined(${$attributes}{basedon}));
    push @{$self->{$style}}, ('\snext'.$snext), if (defined(${$attributes}{next}));

    push @{$self->{$style}}, ('\shidden'), if (${$attributes}{hidden});
    push @{$self->{$style}}, ('\sautoupd'), if (${$attributes}{autoupdate});

    if ($type eq "character") {
        if (${$attributes}{additive}) {
            push @{$self->{$style}}, '\additive';
        } else {
            ${$self->{styles}->{$style}}{plain} = 1;
        }
    } else {
         ${$self->{styles}->{$style}}{plain} = 1;
         ${$self->{styles}->{$style}}{pard}  = 1;
         if ($type eq "section") {
             ${$self->{styles}->{$style}}{secd}  = 1;
         }
    }

    push @{$self->{$style}}, escape_simple($name).";";

    if (${$attributes}{default}) {
        $self->splice_raw($self->{styletbl}, 1, 0, $self->{$style});
    } else {
        $self->add_raw($self->{styletbl}, $self->{$style});
    }

    return $style;
}

# --- These are the color names used in the HTML 4.0 spec. WordPad also uses these
#     names too. However, Microsoft's RTF 1.5 spec uses different color names.

%COLORNAMES = (
    'black'	=> [0, 0, 0],
    'blue'	=> [0, 0, 255],
    'aqua'	=> [0, 255, 255],
    'lime'	=> [0, 255, 0],
    'fuscia'	=> [255, 0, 255],
    'red'	=> [255, 0, 0],
    'yellow'	=> [255, 255, 0],
    'white'	=> [255, 255, 255],
    'navy'	=> [0, 0, 128],
    'teal'	=> [0, 128, 128],
    'green'	=> [0, 128, 0],
    'purple'	=> [128, 0, 128],
    'maroon'	=> [128, 0, 0],
    'olive' 	=> [128, 128, 0],
    'gray'	=> [128, 128, 128],
    'silver'	=> [192, 192, 192],
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

    unless ($self->{colorCnt}) {
        $self->add_raw ($self->{colortbl}, ('\colortbl', ';'));
    }

    foreach ($red, $grn, $blu) {
        carp "Invalid color value: $_.", if ($_<0) or ($_>255);
    }

    if (${$attributes}{default}) {
        carp "Default color will not used by most RTF readers";
        $self->splice_raw ($self->{colortbl}, 1, 1, ("\\red$red", "\\green$grn", "\\blue$blu;") );
        return 0;
    } else {
        $self->add_raw ($self->{colortbl}, ("\\red$red", "\\green$grn", "\\blue$blu;") );
        return ++$self->{colorCnt};
    }
}

sub new_group {
    my $self = shift;
    my $group = [];
    push @{$group}, @_;
    return $group;
}

sub add_group {
    my $self = shift;
    my $section = shift || $self->root();
    my $group = shift || $self->new_group();
    $self->add_raw ($section, $group);
    return $group;
}

sub root {
    my $self = shift;
    return $self->{text};
}

sub splice_raw # splice a raw value into a section
{
    my $self = shift;
    my $section = shift;
    my $position = shift;
    my $length = shift;

    splice @{$section}, $position, $length, @_;
}

sub add_raw # add a raw value to a section
{
    my $self = shift;
    my $section = shift;

    push @{$section}, @_ ;
}


# --- Escape brackets, backslashes and 8-bit characters
sub escape_simple {
    local ($_) = shift;
    s/([\\\{\}])/\\$1/g;	
    s/([\x80-\xff])/sprintf("\\\'\%02x", ord($1))/eg;
    return $_;
}

# --- Escapes special characters to common RTF controls
sub escape_text
{
    local ($_) = escape_simple(shift);
    s/\r/\\par/g;		# carriage returns = new paragraphs
    s/\n/\\line/g;		# escape newlines
    s/\t/\\tab/g;		# escape tabs
    return $_;
}

sub split_text # splits special characters and regular text into list items
{
    my ($line) = shift;

    $line =~ s/\r//g;		# remove carriage returns
    $line =~ s/\n\n/\r/g;		# change double-newlines to new carriage returns

    my (@list) = ();
    local($_);

    foreach (split /(?<=[\n\r\t\\\{\}])|(?=[\n\r\t\\\{\}])/, $line) {
        push @list, escape_text ($_);
    }
    return @list;
}

sub add_text {
    my $self = shift;
    my $group = shift || $self->root();
    my ($arg, $rarg);

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
            $self->add_raw ($group, split_text($arg));
        }
    }
}

sub rtf
{
    my $self = shift;

    unless ($self->{fontCnt}) {
        carp "No default font has been specified";
    }

    return emit_group @{$self->{DOCUMENT}};
}

1;

__END__

=head1 NAME

RTF::Document - Perl extension for generating Rich Text (RTF) Files 

=head1 DESCRIPTION

RTF::Document is a module for generating Rich Text Format (RTF) documents
that can be used by most text converters and word processors.

For a listing of properties, consult the %DOCINFO and %PROPERTIES hashes
in the source code.

=head1 REQUIRED MODULES

    Carp
    POSIX
    Convert::Units::Type 0.33

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

       { bold=>1, underline=>continuous },
       "Bold/Underlined Text\n\n",

       { font_size=>'20pt', font=>$fCourier,
         color_foreground=>$cRed },
       "Bigger, Red and Monospaced.\n\n",

       { style_default=>paragraph },
       { style_default=>character },

       "This is ",
       [ { style=>$sGreen }, "green" ],
       " styled.\n\n"

    );

    open FILE, ">MyFile.rtf";
    binmode FILE;
    print FILE $rtf->rtf();
    close FILE;

=head1 DOCUMENT STRUCTURE

For purposes of using this module, a Rich Text (RTF) Document can be subdivided into
I<groups>. Groups can be considered containers for I<text> and I<controls> (controlling
document and text properties).

For all intents and purposes, a group limits the scope of controls. So if we set
the "bold" character property within a group, the text will be bold only within
that group (until it is turned off within that group).

When generating a RTF document using this module, we are only concerned with the
I<root> group (also called the "Document Area"). (The "Header" groups are taken
care of automatically by this module.)

The Document Area is subdivided into I<sections>. Each section is subdivided into
I<paragraphs>.

=head1 METHODS

Some of the methods are documented below. (Methods not documented here may
be changed in future versions.)

=head2 new

    $rtf = new RTF::Document( \%DocumentProperties );

Creates a new RTF document object.

=head2 root

    $gRoot = $rtf->root();

Returns the "root" group in the RTF document.

=head2 new_group

    $gMyGroup = $rtf->new_group();

Creates a new group (not inside of the RTF document).

=head2 add_group

    $gChildOfRoot = $rtf->add_group();
    $gChildOfChild = $rtf->add_group( $gChild );

Adds a child group to the specfied group. If no group is specified, the "root"
group is assumed.

    $rtf->add_group( $rtf->root(), $gMyGroup );

Adds a group to the specified parent group (in this case, the root group).

=head2 add_raw

    $rtf->add_raw( $group, '\par', "Some Text" );

Adds raw controls and text to the group. This method is intended for internal
use only.

=head2 add_text

    $rtf->add_text( $group, "Some text ", { bold=>1 }, "more text" );

Adds text and controls to a group. Text is escaped.

=head2 add_font

=head2 add_color

=head2 add_style

=head1 PROPERTIES

=head2 Document Properties

=head2 Section Properties

=head2 Paragraph Properties

=head2 Character Properties

=head1 KNOWN ISSUES

This module should be considered in the "alpha" stage. Use at your own risk.

There are no default document or style properties produced by this module,
with the exception of the character set. If you want to make sure that a
I<specific> font, color, or style is used, you must specify it. Otherwise
you rely on the assumptions of whatever RTF reader someone is using.

This module does not insert newlines anywhere in the text, even though some
RTF writers break lines before they exceed 225 characters.  This may or may
not be an issue with some reader software.

Unknown font or style properties will generally be ignored without warning.

This module supports some newer RTF controls (used in Word 95/Word 97) that
may are not understood by older RTF readers.

Once a Font, Color or Style is added, it cannot be changed. No checking
for redundant entries is done.

Generally, it is not possible to reference a not-yet-created Style with the
next or basedon attributes. However, you can use the constances "last",
"self" or "next" to reference the last style added, the current style
being added, or the next style that will be added, respectively.

Specifying properties in a particular order within a group does not
guarantee that they will be emitted in that order. If order matters,
specify them separetly. For instance,

    $rtf->add_text($rtf->root, { style_default=>character, bold=>1 } );

should be (if you want to ensure character styles are reset before setting
bold text):

    $rtf->add_text($rtf->root, { style_default=>character }, { bold=>1 } );

Also note that duplicate properties within the same group won't work. i.e.,
If you want to set "style_default" for both paragraphs and characters, you
must do so in separate groups.

This isn't so much as a bug as the way Perl handles hashes.

=head2 Unimplemented Features

A rather large number of features and control words are not handled in this
version. Among the major features:

=over

=item Annotations and Comments

=item Bookmarks

=item Bullets and Paragraph Numbering

Some support has been added. The backwards-compatability controls for numbered
paragraphs used by older readers has not been added because it is not properly
handled by newer readers.

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

Some minimal controls have been added.

=item Lists and List Tables

Not implemented: List Tables are really a kind of style sheet for lists.
Priority will be given to support generic bullets and paragraph numbering.

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

I<Convert::Units::Type>.

=head1 AUTHOR

Robert Rothenberg <wlkngowl@unix.asb.com>

=head1 LICENSE

Copyright (c) 1999-2000 Robert Rothenberg. All rights reserved.
This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

