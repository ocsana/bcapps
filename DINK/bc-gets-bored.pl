#!/bin/perl

# Creates freedink map tiles (assumes freedinkeditor is up and
# running) in /tmp/dink/

# Useful for testing and smaller maps:
# --ystart,--yend: start/end at this y value, not 1/24
# restricting x isn't useful, doesn't save time

# TODO: lots, this is NOT a finished program

# TODO: redirect the stderr of freedinkedit (or bring it up ourselves)
# since the output is useful

require "/usr/local/lib/bclib.pl";

# defaults
defaults("ystart=1&yend=24");

# find and raise freedink edit window
my($win) = `xdotool search --name dink`;
chomp($win);
system("xdotool windowraise $win; xdotool windowfocus $win");

# using consistent tmp dir for now
mkdir("/tmp/dink/");
chdir("/tmp/dink/");

# TODO: this is testing only
# system("rm /tmp/dink/*");

warn("Caching tile data; if you change maps, use --nocache first time");

# the whole "map"
my($out,$err,$res) = cache_command2("xwd -id $win > wholemap.xwd");
my(%mark);

# slice main map to find dreaded purple tiles of doom(tm)
# 1943571059b5545ec0ef333dd42cb91740b1615b = sha1 of dreaded tile
for $y (1..24) {
  for $x (1..32) {
    # slice and dice
    my($gx,$gy) = ($x*20-20,$y*20-20);
    # this code should be taken out and shot
    my($out,$err,$res) = cache_command2("convert -crop 20x20+$gx+$gy wholemap.xwd - | sha1sum | grep 1943571059b5545ec0ef333dd42cb91740b1615b","age=3600");
    unless ($res) {$mark{$y}{$x} = 1;}
  }
}

# move to top left corner (OK to have two keys down at the same time)
# sleep 5 below is overkill
my($out,$err,$res) = cache_command2("xdotool keydown --window $win Left; xdotool keydown --window $win Up; sleep 5; xdotool keyup --window $win Left; xdotool keyup --window $win Up");

# get wininfo
my($out,$err,$res) = cache_command2("xwininfo -id $win");

# find absolute nw corner
$out=~s/Absolute upper-left X:\s*(\d+)//s;
my($nwx) = $1;
$out=~s/Absolute upper-left Y:\s*(\d+)//s;
my($nwy) = $1;

debug("$nwx/$nwy");

# assuming 32x24 map, Quest for Dorinthia 2 and others have bigger maps
# y pixels: 0-399 used, x pixels 20-619 used (600x400)
# tile geometry: 12x8 (50x50 per tile)

# if skipping screens, do so here

for (1..$globopts{ystart}-1) {xdotoolkey("Down",$win);}

for $y ($globopts{ystart}..$globopts{yend}) {
  for $x (1..32) {

    # skip this tile if: purple (blank), already mapped, or --(xy)(startend)
    if ($mark{$y}{$x} || -f "$x-$y.png") {
      xdotoolkey("Right",$win);
      next;
    }

    xdotoolkey("Return",$win);
    # go to mouse mode to avoid white square
    xdotoolkey("Tab",$win);
    # hide mouse (upper left corner is safe because there's a 20px border)
    system("xdotool mousemove $nwx $nwy");
    # capture (leaving conversion to other prog)
     my($out,$err,$res) = cache_command2("xwd -id $win > $x-$y.xwd");
    # back to white square mode
    xdotoolkey("Tab",$win);
    # back to main map
    xdotoolkey("Escape",$win);
    xdotoolkey("Right",$win);
  }

  # carriage return...
  my($out,$err,$res) = cache_command2("xdotool keydown --window $win Left; sleep 5; xdotool keyup --window $win Left");
  # next row
  xdotoolkey("Down",$win);
}

# not sure why freedinkedit doesn't work with "xdotool key", but
# "holding" key down for a fraction of a second seems to work

# this is really really really ugly and may break so not adding it to bclib.pl

# TODO: allow multiple keystrokes?

sub xdotoolkey {
  my($key,$win) = @_;
  # using system sleep (not Perl sleep) for hopefully more consistency
  # the sleep post-keyup so next xdotool command is delayed
  system("xdotool keydown --window $win $key; sleep 0.05; xdotool keyup --window $win $key; sleep 0.25");
}
