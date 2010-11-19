# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Admin::Window::EditSchema;
use Moose;
extends 'DBR::Admin::Window';

has 'isnew'     => (is => 'rw', isa => 'Bool', default => 0);
has 'schema_id' => (is => 'rw');

sub BUILD {
      my $self = shift;
      print STDERR "BUILD EditSchema\n";

      my $schema = {};
      if(!$self->isnew){
	    my $dbrh = $self->conf_instance->connect or die "Failed to connect";
	    $schema = $dbrh->select( -table => 'dbr_schemas',
				     -fields => 'schema_id handle display_name',
				     -where  => { schema_id => ['d', $self->schema_id] },
				     -single => 1,
				   ) or throw DBR::Admin::Exception( message => "failed to select from dbr_schema $!",
									root_window => $self->win->root );
      }

      $self->add("label1", 'Label', -y => 3, -x => 1, -text => "handle: ");
      $self->add("label2", 'Label', -y => 4, -x => 1, -text => "name:   ");

      my $handle = $self->add( "text1", 'TextEntry', -y => 3, -x => 15,-sbborder => 1,
			       -text => $schema->{handle}
			     );
      my $display = $self->add( "text2", 'TextEntry', -y => 4, -x => 15,-sbborder => 1,
				-text => $schema->{display_name}
			      );

      $self->add(
		 'submit', 'Buttonbox',
		 -y => 6,-x => 38,
		 -buttons   => [
				{
				 -label => '< Save >',
				 -value => 1,
				 -onpress => sub {
				       $self->save(
						   display_name => $display->get || '',
						   handle       => $handle ->get || '',
						  );
				       $self->close;
				 }
				}
			       ]);

      $self->win->draw();
      return 1;


}

sub save{
      my $self = shift;
      my %fields = @_;

      return 1 unless %fields;

      my $dbrh = $self->conf_instance->connect or die "Failed to connect";

      if($self->isnew){
	    my $schema_id = $dbrh->insert( -table => 'dbr_schemas', -fields => \%fields,
					 ) or die DBR::Admin::Exception->new( message => "failed to insert into dbr_schemas",
									      root_window => $self->win->root() );
	    $self->schema_id($schema_id);
	    $self->new(0);
      }else{
	    $dbrh->update( -table => 'dbr_schemas', -fields => \%fields,
			   -where => { schema_id => ['d',$self->schema_id ] },
			 ) or die DBR::Admin::Exception->new( message => "failed to update dbr_schemas",
									  root_window => $self->win->root() );
      }

      return 1;
}


1;
