#!/bin/perl

# Usage: $0 directory-where-mod-is (last part of dir will be used as map name)

# NOTE: you must run "ffrextract" once with no arguments in
# /usr/share/dink/dink for this to work (running it at toplevel will
# create BMPs in subdirectories as needed). See also "alpha" in oneliners.sh

# must also convert all D-MOD specific BMPs to transparent PNGs

# A direct attempt at creating maps for Dink D-Mods

require "/usr/local/lib/bclib.pl";

my($dinkdir) = "/usr/share/dink/dink";

# the 4-byte integers at the start of a sprite (before the 14 character script)

my(@sdata) = ("xpos", "ypos", "seq", "frame", "type", "size",
"active", "rotation", "special", "brain");

# the 4 13-byte scripts (3 of which are unused, and I don't need the
# 4th, but...)

my(@scripts) = ("main", "hit", "die", "talk");

# the 4-byte integer field that appear after the 4 scripts

my(@smore) = ("speed", "base_walk", "base_idle", "base_attack",
"base_hit", "timer", "que", "hard", "alt.left", "alt.top",
"alt.right", "alt.bottom", "prop", "warp_map", "warp_x", "warp_y",
"parm_seq", "base_die", "gold", "hitpoints", "strength", "defense",
"exp", "sound", "vision", "nohit", "touch_damage");

my($moddir) = @ARGV;
# since I'm going to chdir to another dir, need moddir
unless ($moddir=~m%^/%) {$moddir = "$ENV{PWD}/$moddir";}
# and name
$name = $moddir;
$name=~s%^.*/%%;
unless ($name) {die "Usage: $0 <directory> [cannot use current dir + dir name can't end in slash]";}

# maps created here
system("mkdir -p /usr/local/etc/DINK/MAPS/$name");
dodie('chdir("/usr/local/etc/DINK/MAPS/$name")');

my(%dinksprites) = read_dink_ini();

# how many screens?
my($ns) = int((-s "$moddir/map.dat")/31280);
open(A,"$moddir/map.dat")||die("Can't open $moddir/map.dat");
my($buf);

# go through screens
for $i (1..$ns) {
  debug("SCREEN $i\n\n");

  # testing
#  unless ($i==25) {next;}

  seek(A,31280*($i-1),SEEK_SET);
  read(A,$buf,31820);
  dink_render_screen($buf,"screen$i.jpg");
  dink_sprite_data($buf,"screen$i.jpg");
}

# Given the 31820 byte chunk representing a screen, recreate screen in
# given filename (without sprites for now)

sub dink_render_screen {
  my($data,$file) = @_;

  # TODO: dink_sprite_data should also return or neither sub should be called
  if (-f $file) {return;}

  local(*A);
  open(A,"|montage \@- -tile 12x8 -geometry +0+0 $file");

  # the tiles
  for $y (1..8) {
    for $x (1..12) {
      $data=~s/^.{20}(.)(.)(.{58})//s;
      # tile number and screen number (wraparound if $t>=128)
      my($t,$s) = (ord($1),2*ord($2)+1);
      if ($t>=128) {$s++; $t-=128;}
      # top left pixel
      my($px,$py) = ($t%12*50,int($t/12)*50);
      print A dink_tile_png($s,$px,$py),"\n";
    }
  }
  close(A);
}

# given an image, determine sprite data and overlay it onto image

sub dink_sprite_data {
  my($data,$image) = @_;
  my(@sprites);

  # sprite data starts at 8020, but first sprite is always blank
  $data=~s/^.{8240}//s;

  # 100 sprites
  my($count) = 0;

  while ($data=~s/^(.{220})//s) {
    if (++$count>100) {last;}
    my($sprite) = $1;

    # silently ignore null
    if ($sprite=~/^\0+$/) {next;}

    my(%sprite);
    # ints, scripts, more ints
#    debug("SCRIPTS",@scripts);
    for $i (@sdata) {$sprite=~s/(.{4})//s;$sprite{$i} = unpack("i4",$1);}
    for $i (@scripts) {$sprite=~s/(.{13})//s;$sprite{"${i}_script"}=$1;}
    for $i (@smore) {$sprite=~s/(.{4})//s;$sprite{$i} = unpack("i4",$1);}

    # TODO: more tests here to see when NOT to display sprite
    # if not in all visions, invisible or inactive, don't show
    if ($sprite{vision} || $sprite{type}==3 || !$sprite{active}) {next;}
    # not sure about this one, so separating it out
#    if ($sprite{ypos}<0) {next;}

    # find transparent PNG version of this sprite (or create it)
    $sprite{fname} = dink_sprite_png(\%sprite);

    debug("<sprite>",dump_var("SPRITE",\%sprite),"</sprite>");
#    debug("FNAME: $fname");

    # figure out true x y coords
    ($sprite{xdelta},$sprite{ydelta}) = split(/\s+/, $dinksprites{"$sprite{seq}.$sprite{frame}"});

    # the 20 appears to be an artifact of freedinkedit's left padding?!
    $sprite{xpos2}=$sprite{xpos}-$sprite{xdelta}-20;
    $sprite{ypos2}=$sprite{ypos}-$sprite{ydelta};
#    $sprite{xpos2}=$sprite{xpos}-$sprite{xdelta}*$sprite{size}/100;
#    $sprite{ypos2}=$sprite{ypos}-$sprite{ydelta}*$sprite{size}/100;

    # TODO: figure out when freedink does/doesn't render a sprite,
    # below is guesswork
#    if ($sprite{ypos2}>400)

    # the z coordinate (higher values over lower values); default is que
    $sprite{z} = $sprite{que};
    # if background sprite, lowest value
    if ($sprite{type}==0) {$sprite{z} = -Infinity;}
    # special case for 0
    if ($sprite{que}==0) {$sprite{z} = $sprite{ypos};}

    push(@sprites,\%sprite);
  }

  # sort by z value
  my(@overlays);
  my($tempcount);
  for $j (sort {$a->{z} <=> $b->{z}} @sprites) {

    # TODO: this is probably bad
    unless ($j->{fname}) {next;}

    ++$tempcount;
#    unless ($tempcount==7) {next;}

#    push(@overlays, "-page +$j->{xpos2}+$j->{ypos2} $j->{fname}");
    push(@overlays, "-page +$j->{xpos2}+$j->{ypos2} '$j->{fname}\[$j->{size}%\]'");
  }

  my($overlays) = join(" ",@overlays);
  # convert doesnt like +-
  $overlays=~s/\+\-/-/g;
  debug("OL: $overlays");

  my($out,$err,$res) = cache_command2("convert -page +0+0 $image $overlays -layers flatten temp-$image");
}

# reads the standard Dink.ini file (not mod-specific), returns a
# number-to-sprite-hash with additional sprite info

sub read_dink_ini {
  my(%result);

  # read standard dink.ini, my addition to it and game-specific ini
  # (later lines will override earlier ones)
  my(@lines) = split(/\n/, read_file("/usr/share/dink/dink/Dink.ini"));
  push(@lines, split(/\n/, read_file("$bclib{githome}/DINK/dink-more.ini")));
  push(@lines,split(/\n/, read_file(glob("$moddir/[Dd][iI][nN][kK].[iI][nN][iI]"))));

  for $i (@lines) {
    if ($i=~m%^load_sequence(_now)?\s+(.*?)\s+(\d+)%){$result{$3}=uc($2);}
    if ($i=~/^SET_SPRITE_INFO\s+(\d+)\s+(\d+)\s+(.*)$/) {$result{"$1.$2"}=$3;}
  }
  return %result;
}

# finds or creates the file that is the transparent PNG version of a
# given sprite (sent as hash)

sub dink_sprite_png {
  my($spriteref) = @_;
  my(%sprite) = %{$spriteref};

  # the "base" path
  my($path) = sprintf("$dinksprites{$sprite{seq}}%02d.bmp.png",$sprite{frame});

  # convert backslashes to forward ones
  $path=~s%\\+%/%g;
  # TODO: this should really be a subroutine (wildcard glob)
  $path=~s/([a-z])/"\[".lc($1).uc($1)."\]"/ieg;

  # search in moddir first, then dinkdir
  # note Perl glob breaks on these, using ls instead
  my($out,$err,$res) = cache_command2("ls $moddir/$path $dinkdir/$path");
  chomp($out);
  return $out;
}

# returns the transparent PNG for a tile, given as $s, $px, $py

sub dink_tile_png {
  my($s,$px,$py) = @_;

  # check moddir and then main dir
  for $i ($moddir,$dinkdir) {
    my($path) = sprintf("$i/tiles/ts%02d.bmp",$s);
    $path=~s/([a-z])/"\[".lc($1).uc($1)."\]"/ieg;
    my($out,$err,$res) = cache_command2("ls $path");
    # TODO: ignoring spaces here may break things
    $out=~s/\s.*//s;
    # if we don't find it, continue
    unless ($out) {next;}
    # we did find it, now check for tile
    my($tile) = "$out-$px-$py.png";
    # create it if it doesnt exist
    unless (-f $tile) {
    # create using convert
      ($out,$err,$res) = cache_command2(debug("convert -crop 50x50+$px+$py $out $tile"));
      # TODO: you may have to be root for above to work = icky
      if ($res) {die("ERROR: $err")};
    }
    return $tile;
  }
}


