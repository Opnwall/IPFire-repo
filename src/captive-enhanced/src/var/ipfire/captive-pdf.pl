# Unicode coupon PDF renderer shared by both IPFire captive management pages.
# GPL-3.0-or-later. The bundled font has its separate SIL OFL license.
package CaptivePDF;
use strict;
use warnings;
use utf8;
use Encode qw(decode encode FB_DEFAULT);
use Compress::Zlib qw(compress);
use PDF::API2::Basic::PDF::Utils;
use PDF::API2;
our $FONT = '/usr/share/fonts/captive-enhanced/CaptiveSansCJK-Regular.ttf';
our $IMAGE = '/srv/web/ipfire/html/captive/assets/ipfire.png';

sub unicode {
    my ($value)=@_;
    $value='' unless defined $value;
    return utf8::is_utf8($value) ? $value : decode('UTF-8',$value,FB_DEFAULT);
}
sub fit_size {
    my ($text,$font,$value,$width,$maximum,$minimum)=@_;
    my $size=$maximum;
    $text->font($font,$size);
    while ($size>$minimum && $text->advancewidth($value)>$width) {
        $size-=0.5; $text->font($font,$size);
    }
    return $size;
}
sub line {
    my ($page,$font,$value,$x,$y,$width,$maximum,$minimum,$center)=@_;
    $value=unicode($value);
    my $text=$page->text;
    my $size=fit_size($text,$font,$value,$width,$maximum,$minimum);
    if ($text->advancewidth($value)>$width) {
        my $suffix="\x{2026}";
        chop($value) while length($value) && $text->advancewidth($value.$suffix)>$width;
        $value.=$suffix;
    }
    $x+=($width-$text->advancewidth($value))/2 if $center;
    $text->translate($x,$y); $text->text($value);
    return $size;
}
sub wrap {
    my ($text,$value,$width)=@_;
    my @lines; my $line='';
    for my $char (split //,unicode($value)) {
        if (length($line) && $text->advancewidth($line.$char)>$width) {push @lines,$line; $line='';}
        $line.=$char;
    }
    push @lines,$line if length($line);
    return @lines;
}
# PDF::API2 versions in IPFire write non-BMP code points as plain hex, not
# UTF-16 surrogate pairs. Build a valid map for just the glyphs actually used.
sub unicode_map {
    my ($font)=@_;
    my @entries;
    for my $gid (0..$font->glyphNum()-1) {
        next unless $font->subvec($gid);
        my $cp=$font->uniByCId($gid);
        next unless defined($cp) && $cp>0 && $cp<=0x10ffff;
        push @entries, sprintf('<%04X> <%s>', $gid, uc(unpack('H*',encode('UTF-16BE',chr($cp)))));
    }
    my $stream="/CIDInit /ProcSet findresource begin\n12 dict begin\nbegincmap\n/CIDSystemInfo << /Registry (Adobe) /Ordering (UCS) /Supplement 0 >> def\n/CMapName /CaptiveUnicode def\n/CMapType 2 def\n1 begincodespacerange\n<0000> <FFFF>\nendcodespacerange\n";
    while (@entries) {
        my @batch=splice(@entries,0,100);
        $stream.=scalar(@batch)." beginbfchar\n".join("\n",@batch)."\nendbfchar\n";
    }
    $stream.="endcmap\nCMapName currentdict /CMap defineresource pop\nend end\n";
    my $map=PDFDict();
    $map->{'Type'}=PDFName('CMap');
    $map->{' stream'}=compress($stream); $map->{' nofilt'}=1;
    $map->{'Filter'}=PDFName('FlateDecode');
    $font->{' apipdf'}->new_obj($map); $font->{'ToUnicode'}=$map;
}
sub generate {
    my (%args)=@_;
    die 'Unicode coupon font is missing' unless -r $FONT;
    my $pdf=PDF::API2->new;
    $pdf->info(Title=>unicode($args{title}),Creator=>'IPFire Captive Enhanced');
    my $font=$pdf->ttfont($FONT,-encode=>'utf8',-unicodemap=>0,-nosubset=>1);
    my $image=-r $IMAGE ? $pdf->image_png($IMAGE) : undef;
    my $labels=$args{labels} || {};
    my $rows=$args{coupons} || {};
    my @records=map {$rows->{$_}} sort {$a <=> $b} keys %$rows;
    my ($page_w,$page_h)=(595.276,841.890);
    my ($margin,$gap,$height)=(28,12,180);
    my $width=($page_w-2*$margin-$gap)/2;
    # Exporting an empty list still produces a valid document with a clear label.
    @records=([0,'',0,unicode($labels->{empty})]) unless @records;
    while (@records) {
        my $page=$pdf->page; $page->mediabox($page_w,$page_h);
        my @batch=splice(@records,0,8);
        for my $i (0..$#batch) {
            my ($issued,$code,$duration,$remark)=@{$batch[$i]};
            my $x=$margin+($i%2)*($width+$gap);
            my $top=$page_h-$margin-int($i/2)*($height+$gap);
            my $bottom=$top-$height;
            my $inner=$width-24;
            my $gfx=$page->gfx; $gfx->strokecolor('#777777'); $gfx->linewidth(0.5);
            $gfx->rect($x,$bottom,$width,$height); $gfx->stroke;
            line($page,$font,$args{title},$x+12,$top-23,$inner,17,10,1);
            # Leave one visual blank line between the coupon title and details.
            line($page,$font,unicode($labels->{company}).': '.unicode($args{company}),$x+12,$top-52,$inner,10,8,0);
            line($page,$font,unicode($labels->{ssid}).': '.unicode($args{ssid}),$x+12,$top-67,$inner,10,8,0);
            my $text=$page->text;
            fit_size($text,$font,unicode($code),$inner,26,10);
            my @code_lines=CaptivePDF::wrap($text,$code,$inner);
            # Codes are never shortened: long legacy codes wrap instead of clipping.
            for my $j (0..$#code_lines) {
                $text->translate($x+12+($inner-$text->advancewidth($code_lines[$j]))/2,$top-100-$j*13);
                $text->text($code_lines[$j]);
            }
            my $duration_text=$args{duration}->($duration // 0);
            line($page,$font,unicode($labels->{validity}).': '.unicode($duration_text),$x+12,$top-127,$inner,11,8,0);
            my $note=$page->text; $note->font($font,9);
            my @notes=CaptivePDF::wrap($note,unicode($labels->{remark}).': '.unicode($remark),$inner-42);
            for my $j (0..($#notes<1?$#notes:1)) {
                my $value=$notes[$j]; $value.="\x{2026}" if $j==1 && @notes>2;
                line($page,$font,$value,$x+12,$top-145-$j*13,$inner-42,9,8,0);
            }
            line($page,$font,'Powered by IPFire / Umberto Parma',$x+12,$bottom+9,$inner-42,6.5,6,0);
            if ($image) {
                my ($iw,$ih)=($image->width,$image->height);
                my $scale=28/($iw>$ih?$iw:$ih);
                my $g=$page->gfx;
                $g->image($image,$x+$width-40,$bottom+9,$iw*$scale,$ih*$scale);
            }
        }
    }
    unicode_map($font);
    return $pdf->stringify;
}
1;
