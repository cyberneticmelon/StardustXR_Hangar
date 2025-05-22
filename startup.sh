#!/usr/bin/env bash

xwayland-satellite :10 &
export DISPLAY=:10

./protostar/target/debug/hexagon_launcher &
./flatland/target/debug/flatland &
./atmosphere/target/debug/atmosphere show the_grid &
./gravity/target/debug/gravity 0.7 0 0 ./client-template/target/debug/client-template &

WAYLAND_DISPLAY=$FLAT_WAYLAND_DISPLAY ./non-spatial-input/target/debug/manifold | ./non-spatial-input/target/debug/simular &
