# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Query::Dummy;

use Carp;
use overload 
  #values
  '""' => sub { '' },
  '0+' => sub { 0 },

  #operators
  '+'  => sub { $_[1] },
  '-'  => sub { return $_[2] ? $_[1] : 0 - $_[1] },

  '*'  => sub { 0 },
  '/'  => sub { 0 },

 'fallback' => 1,
 'nomethod' => sub {croak "Dummy object: Invalid operation '$_[3]' The ways in which you can use Dummy objects is limited"}
 ;

our $AUTOLOAD;
sub AUTOLOAD {  return shift }

1;
