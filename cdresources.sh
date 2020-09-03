#!/bin/bash
siteRoot=$(echo $PWD | sed 's_\(.*\)/www/\([a-z.]*\)/.*_\1/www/\2_')
cd $(echo $siteRoot)/frontend/themes/*/resources
