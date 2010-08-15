package Leyland::Parser;

use strict;
use warnings;
use Exporter::Declare;

export get Leyland::Parser::Route { caller->add_route(['get'],  @_) }
export put Leyland::Parser::Route { caller->add_route(['put'],  @_) }
export del Leyland::Parser::Route { caller->add_route(['del'],  @_) }
export any Leyland::Parser::Route { caller->add_route(['any'],  @_) }
export post Leyland::Parser::Route { caller->add_route(['post'], @_) }
export prefix codeblock { caller->set_prefix(@_) }

1;
