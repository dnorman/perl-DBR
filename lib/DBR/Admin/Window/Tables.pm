# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Admin::Window::Tables;
use Moose;
use Curses;

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

      my $listbox = $self->add( 'tablelist', 'Listbox',
				-y => 1, -width => 25, -vscrollbar => 1,
				-title => "Tables", -border => 1,
				-values => [ sort { lc($labels{$a}) cmp lc($labels{$b}) } keys %labels ],
				-labels => \%labels,
				-onchange => sub {
				      # $self->spawn('Fields',
				      # 		   title       => $self->schema_name.'.'.$labels{$table_id} . ' fields',
				      # 		   table_id    => $table_id,
				      # 		   table_name  => $labels{ $table_id },
				      # 		   schema_id   => $self->schema_id,
				      # 		   schema_name => $self->schema_name,
				      # 		  )
				      $self->win->getobj('fieldlist')->focus;
				},
				-onselchange => sub { 
				      my $table_id = $_[0]->get_active_value;
				      $self->list_relationships( $table_id, $labels{$table_id} );
				      $self->list_fields( $table_id, $labels{$table_id} );
				}
			      );
      $listbox->draw;
      $listbox->focus;

      $self->win->set_binding( sub { $self->focus_t } , 't');
      $self->win->set_binding( sub { $self->focus_r } , 'r');
      $self->win->set_binding( sub { $self->focus_f } , 'f');
      $listbox->onFocus(sub { $listbox->clear_selection });

      $self->win->set_focusorder('tablelist', 'rellist','fieldlist', 'close');
}

sub focus_t{ my $o = shift->win->getobj('tablelist') or return; $o->focus}
sub focus_r{ my $o = shift->win->getobj('rellist')   or return; $o->focus}
sub focus_f{ my $o = shift->win->getobj('fieldlist') or return; $o->focus}

sub list_relationships{
      my $self = shift;
      my $table_id = shift;
      my $table_name = shift;

      my $dbrh = $self->conf_instance->connect or die "Failed to connect";

      my $rows = $dbrh->select(
			       -table => 'dbr_relationships',
			       -fields => 'relationship_id from_name from_table_id from_field_id to_name to_table_id to_field_id type',
			       -where => [
					  [ {from_table_id => $table_id },
					    {to_table_id   => $table_id } ]
					 ]
			      ) or throw DBR::Admin::Exception( message => "failed to select from dbr_relationships",
								root_window => $self->get_win->root()
							      );

      my @rels;
      foreach my $row ( @$rows ){
	    my ($this,$that,$symbol);
	    if( $row->{from_table_id} == $table_id){
		  $this = 'to'; $that = 'from'; $symbol = '->';
	    }elsif($row->{to_table_id} == $table_id){
		  $this = 'from'; $that = 'to'; $symbol = '<-'
	    }else{
		  next;
	    }

	    push @rels, {
			 relationship_id => $row->{relationship_id},
			 name  => $row->{$this . '_name'},
			 display => $symbol . ' ' . $row->{$this . '_name'},
			}
      }


      my %labels = map { $_->{relationship_id} => $_->{display} } @rels;

      $self->win->delete('rellist');
      my $listbox = $self->add( 'rellist', 'Listbox',
				-y => 1, -x => 26, -width => 25, -height => 7, -vscrollbar => 1,
				-title => "Relationships", -border => 1,
				-values => [ map{ $_->{relationship_id} } sort { lc($a->{name}) cmp lc($b->{name}) } @rels ],
				-labels => \%labels,
				-onchange => sub {
				      my $fid = $_[0]->get;
				      $self->spawn( 'Relationship',
						    # field_id => $fid,
						    # title    =>
						    # $self->schema_name . '.' . $table_name . '.' . $labels{$fid},
						    # dimensions  => '50x15',
						    # bordercolor => 'blue'
						  ) },
			      );

      $listbox->onFocus(sub { $listbox->clear_selection });
      $listbox->set_binding( sub { $self->focus_t } , KEY_LEFT);
      $listbox->draw;
}

sub list_fields{
      my $self = shift;
      my $table_id = shift;
      my $table_name = shift;

      my $dbrh = $self->conf_instance->connect or die "Failed to connect";

      my $fields = $dbrh->select( -table => 'dbr_fields',
				  -fields => 'field_id table_id name data_type is_nullable is_signed max_value display_name is_pkey index_type trans_id',
				  -where => { table_id => [ 'd',$table_id ] },
				) or throw DBR::Admin::Exception( message => "failed to select from dbr_fields $!",
								  root_window => $self->win->root()
								);
      my %labels = map { $_->{field_id} => $_->{name} } @$fields;

      $self->win->delete('fieldlist');
      my $listbox = $self->add( 'fieldlist', 'Listbox',
				-y => 8, -x => 26, -width => 25, -vscrollbar => 1,
				-title => "Fields", -border => 1,
				-values => [ sort { lc($labels{$a}) cmp lc($labels{$b}) } keys %labels ],
				-labels => \%labels,
				-onchange => sub {
				      my $fid = $_[0]->get;
				      $self->spawn( 'Field',
						    field_id => $fid,
						    title    =>
						    $self->schema_name . '.' . $table_name . '.' . $labels{$fid},
						    dimensions  => '50x15',
						    bordercolor => 'blue'
						  ) },
			      );

      $listbox->onFocus( sub { $listbox->clear_selection });
      $listbox->set_binding( sub { $self->focus_t } , KEY_LEFT);
      $listbox->draw;
}

1;
