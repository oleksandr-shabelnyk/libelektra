#!/bin/sh
cd @CMAKE_INSTALL_PREFIX@/@install_directory@

cd elektrad
npm run start:prod
