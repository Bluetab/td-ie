#!/bin/sh

set -o errexit
set -o xtrace

bin/td_ie eval 'Elixir.TdIe.Release.migrate()'
bin/td_ie start
