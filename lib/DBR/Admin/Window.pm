# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License as
# published by the Free Software Foundation.

package DBR::Admin::Window;
use Moose;

has 'conf_instance' => (is => 'ro', required => 1);
has 'parent'        => (is => 'ro', required => 1);
#has 'parenttitle' => (is => 'ro');
has 'id'            => (is => 'ro');
has 'win'           => (is => 'rw');
has 'bordercolor'   => (is => 'ro');
has 'title'         => (is => 'ro');
has 'dimensions'    => (is => 'ro');
has 'height'        => (is => 'ro');
has 'onclose'       => (is => 'ro');

# Basic window construction goes here ( base class )
sub BUILD {
      my $self = shift;
      print STDERR "BUILD Window\n";

      my %extra;
      if($self->dimensions){
	    my ($width,$height) = split(/\D+/, $self->dimensions);
	    $extra{-width}   = $width;
	    $extra{-height}  = $height;
	    $extra{-centered} = 1;
      }


      my $w = $self->parent->add(
				 $self->id, 'Window',
				 -border => 1, -bfg => $self->bordercolor,
				 -title  => $self->title || ucfirst($self->id),
				 -titlereverse => 0,
				 #-y      => 1,
				 %extra
				);

      $w->add( 'close', 'Buttonbox',
	       -buttons => [{  -label    => "[ X ]",
			       -onpress  => sub { $self->close }
			    }],
	       -x => $w->width - 8
	     );
      $w->set_binding( sub { $self->close }  , "\e");
      $self->win( $w );

      $w->focus();
}

sub spawn {
      my ($self, $module, %params) = @_;

      my $class = __PACKAGE__ . '::' . $module;
      eval "require $class" or die "Failed to load $class\n$@";

      print STDERR "SPAWN '$module'\n" ;
      return $class->new(
			 id           => $module,
			 parent       => $self->parent,
			 parent_title => ucfirst($self->id),
			 conf_instance => $self->conf_instance,
			 %params
			);

}

sub add{
      shift->win->add(@_);
}


###################
sub close {
      my $self = shift;

       if ($self->id eq 'main') {
	     exit;
       }

      $self->parent->delete($self->id);
      $self->parent->focus();
      $self->parent->draw();

      if (ref($self->onclose) eq 'CODE'){
	    $self->onclose->();
      }
}




1;
