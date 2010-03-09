# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Admin::Window::Tables;
use Moose;
extends 'DBR::Admin::Window';

has schema_id   => (is => 'ro', required => 1);
has schema_name => (is => 'ro', required => 1);

sub BUILD {
      my $self = shift;

      my $dbrh = $self->conf_instance->connect or die "Failed to connect";
      my $tables = $dbrh->select( -table  => 'dbr_tables',
				  -fields => 'table_id schema_id name display_name is_cachable',
				  -where  => { schema_id => ['d',$self->schema_id] },
				 ) or throw DBR::Admin::Exception( message => "failed to select from dbr_tables $!",
								   root_window => $self->win->root );

      my %labels = map { $_->{table_id} => $_->{name} } @$tables;

      my $listbox = $self->add( 'tablelistbox', 'Listbox',
				-y => 2, -width => 25, -vscrollbar => 1,
				-title => "Tables", -border => 1,
				-values => [ sort { lc($labels{$a}) cmp lc($labels{$b}) } keys %labels ],
				-labels => \%labels,
				-onchange => sub {
				      my $table_id = $_[0]->get;
				      $self->spawn('Fields',
						   title       => $self->schema_name.'.'.$labels{ $table_id} . ' fields',
						   table_id    => $table_id,
						   table_name  => $labels{ $table_id },
						   schema_id   => $self->schema_id,
						   schema_name => $self->schema_name,
						  )
				},
				-onselchange => sub { print STDERR "Active is: " . $_[0]->get_active_value . "\n" }
			      );
      $listbox->draw;
      $listbox->focus;

}

1;
