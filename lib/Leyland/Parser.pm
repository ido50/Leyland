package Leyland::Parser;

use strict;
use warnings;
use Exporter::Declare '-magic';

default_export get Leyland::Parser::Route { caller->add_route('get',  @_) }
default_export put Leyland::Parser::Route { caller->add_route('put',  @_) }
default_export del Leyland::Parser::Route { caller->add_route('del',  @_) }
default_export any Leyland::Parser::Route { caller->add_route('any',  @_) }
default_export post Leyland::Parser::Route { caller->add_route('post', @_) }
default_export prefix codeblock { caller->set_prefix(@_) }

1;
