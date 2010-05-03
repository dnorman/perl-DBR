# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Admin::Window::Schema;
use Moose;
use Curses;

extends 'DBR::Admin::Window';

has schema_id   => (is => 'ro', required => 1);
has schema_name => (is => 'ro', required => 1);

my $dtlist = DBR::Config::Field->list_datatypes;
my %dtmap = map { $_->{id} => $_ } @$dtlist;

my $trans = DBR::Config::Trans::list_translators();
my %transmap = map { $_->{id} => $_ } @$trans;

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
				-y => 1, -width => 26, -vscrollbar => 1,
				-title => "Tables", -border => 1,
				-values => [ sort { lc($labels{$a}) cmp lc($labels{$b}) } keys %labels ],
				-labels => \%labels,
				-onchange => sub { $self->win->getobj('fieldlist')->focus },
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
      $listbox->set_binding( sub { $self->close } , KEY_LEFT   );
      $listbox->onFocus(     sub { $listbox->clear_selection } );

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
      my %fields = map { $_->{field_id} => $_         } @$fields;

      $self->win->delete('fieldlist');
      my $listbox = $self->add( 'fieldlist', 'Listbox',
				-y => 8, -x => 26, -width => 25, -vscrollbar => 1,
				-title => "Fields", -border => 1,
				-values => [ sort { lc($labels{$a}) cmp lc($labels{$b}) } keys %labels ],
				-labels => \%labels,
				-onchange => sub {
				      my $field_id = $_[0]->get;
				      $self->spawn( 'Field',
						    field_id => $field_id,
						    title    =>
						    $self->schema_name . '.' . $table_name . '.' . $labels{$field_id},
						    dimensions  => '50x15',
						    bordercolor => 'blue'
						  ) },
				-onselchange => sub {

				      my $field_id = $_[0]->get_active_value;
				      $self->field_detail( $fields{$field_id}, $table_name );

				}
			      );

      $listbox->onFocus( sub { $listbox->clear_selection });
      $listbox->set_binding( sub { $self->focus_t } , KEY_LEFT);
      $listbox->draw;
}

sub field_detail{
      my $self = shift;
      my $field = shift;
      my $table_name = shift;

      my $box = $self->detail_box( $table_name . '.' . $field->{name} );

      my @lines;
      push @lines, '"'. $field->{display_name} .'"' if $field->{display_name};

      my $typeref = $dtmap{ $field->{data_type} } || {};
      push @lines, 'Type:  ' . $typeref->{handle} . "($field->{max_value})";


      my @parts;
      push @parts, $field->{is_signed}   ? 'SIG'  : 'UNSIG';
      push @parts, $field->{is_nullable} ? 'NULL' : 'NOTNULL';
      push @parts, 'PK' if $field->{is_pkey};

      push @lines, 'Flags: ' . join(' ', @parts);

      if( $field->{trans_id} ){
	    my $trans = $transmap{ $field->{trans_id} };
	    push @lines, "Trans: $trans->{name}";
      }

      $box->add('field_basics', 'Label',  -text => join("\n", @lines) );
      $box->draw;

      return 1;

}

sub detail_box{
      my $self = shift;
      my $title = shift;
      print STDERR "DETAIL BOX\n";

      $self->win->delete('detail_box');
      $self->{detail_box} = $self->add(
				       'detail_box', 'Window',
				       -border => 1, -bfg => $self->bordercolor,
				       -title  => $title || 'Details',
				       -titlereverse => 1,
				       -y      => 1,
				       -x      => 51,
				      );
      return $self->{detail_box};
}

1;
