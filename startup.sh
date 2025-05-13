#!/usr/bin/env bash

xwayland-satellite :10 &
export DISPLAY=:10

./prefix/bin/hexagon_launcher &
./prefix/bin/flatland &
./prefix/bin/atmosphere show the_grid &
./prefix/bin/client-template

./prefix/bin/gravity 0 0 -0.5 konsole
