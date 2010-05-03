# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Admin::Window::MainMenu;

use strict;
use Moose;

extends 'DBR::Admin::Window';

my $maintitle = q#
 ____  ____  ____       _       _           _       
|  _ \| __ )|  _ \     / \   __| |_ __ ___ (_)_ __  
| | | |  _ \| |_) |   / _ \ / _` | '_ ` _ \| | '_ \ 
| |_| | |_) |  _ <   / ___ \ (_| | | | | | | | | | |
|____/|____/|_| \_\ /_/   \_\__,_|_| |_| |_|_|_| |_|

Global keys:
Control-Q: Quit
Tab: next input widget
Enter or right-arrow: select
Up/Down arrows: previous/next item in current input widget
Mouse may be supported depending on your terminal program#;


my %menu_labels = (
		   'SchemaList'    => 'Schemas',
		  );
my @menu_values = keys %menu_labels;

####################
sub BUILD {
      my ($self) = @_;

      print STDERR "BUILD MainMenu\n";
      my $listbox = $self->add(
			       'mainMenulist', 'Listbox',
			       -y        => 2,
			       -width    => 15,
			       -height   => 4,
			       -values   => \@menu_values,
			       -labels   => \%menu_labels,
			       -onchange => sub { $self->spawn(shift->get) },
			      );

      my $label = $self->add(
			     "instructions_label", 'Label',
			     -text => $maintitle,
			     -y => 6,
			    );

      $listbox->focus();
      $listbox->onFocus(sub { $listbox->clear_selection });

}

1;
