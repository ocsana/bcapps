#!/bin/perl

# Given a KML on my server (bcinfo3), create google map with that KML
# file, using randomization to prevent caching

require "/usr/local/lib/bclib.pl";

print "Content-type: text/html\n\n";

my($str) = << "MARK";
<html><head>
<meta name="viewport" content="initial-scale=1.0, user-scalable=no" />
<style type="text/css">
  html { height: 100% }
  body { height: 100%; margin: 0px; padding: 0px }
  #map_canvas { height: 100% }
</style>
<script type="text/javascript" src="http://maps.google.com/maps/api/js?sensor=false"></script>
<script type="text/javascript">
function initialize() {
 var myLatLng = new google.maps.LatLng(0,0);
 var myOptions = {zoom: 2, center: myLatLng, mapTypeId: google.maps.MapTypeId.TERRAIN};
 var map = new google.maps.Map(document.getElementById("map_canvas"),myOptions);
}
</script></head>
<body onload="initialize()"><div id="map_canvas" style="width:100%; height:100%"></div></body></html>
MARK
;

print $str;
