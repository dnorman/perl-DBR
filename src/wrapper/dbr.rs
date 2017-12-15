use std::cell::RefCell;
use perl_xs::{ IV, DataRef };
use adapter::Adapter;

use context::{Context,ContextOptions};

xs! {
    package DBR;

    sub new(ctx, class: String) {
        println!("new {:?}", class);
        let opts = ContextOptions::from_perl_kv(&mut ctx, 1);
        println!("Context Options {:?}", opts );

        let context = Context::new(opts);

        context.close_all_filehandles(); // Make it safer for forking
        ctx.new_sv_with_data(RefCell::new(context)).bless(&class)
    }
    
    sub flush_handles(_ctx, this: DataRef<RefCell<IV>>) {
        this.borrow_mut().close_all_filehandles();
    }

//     sub setlogger {
//       my $self = shift;
//       $self->{logger} = shift;
// }

// sub session { $_[0]->{session} }

// sub connect {
//       my $self = shift;
//       my $name = shift;
//       my $class = shift;
//       my $tag = shift;
//       my $flag;

//       if ($class && $class eq 'dbh') {	# legacy
// 	    $flag = 'dbh';
// 	    $class = undef;
//       }

//       my $instance = DBR::Config::Instance->lookup(
// 						   dbr    => $self,
// 						   session => $self->{session},
// 						   handle => $name,
// 						   class  => $class,
//                                                    tag    => $tag
// 						  ) or return $self->_error("No config found for db '$name' class '$class'");

//       return $instance->connect($flag);

// }

// sub get_instance {
//       my $self = shift;
//       my $name = shift;
//       my $class = shift;
//       my $tag = shift;
//       my $flag;

//       if ($class && $class eq 'dbh') {	# legacy
// 	    $flag = 'dbh';
// 	    $class = undef;
//       }

//       my $instance = DBR::Config::Instance->lookup(
// 						   dbr    => $self,
// 						   session => $self->{session},
// 						   handle => $name,
// 						   class  => $class,
//                                                    tag    => $tag
// 						  ) or return $self->_error("No config found for db '$name' class '$class'");
//       return $instance;
// }

// sub get_schema {
//       my $self = shift;
//       my $handle = shift;
      
//       my $schema = DBR::Config::Schema->new(
//                                     session => $self->{session},
//                                     instance_id => -1, # reflection use only
//                                     handle => $handle
//                                  ) or return $self->_error("No schema found for handle '$handle'");
//       return $schema;
// }

// sub timezone{
//       my $self = shift;
//       my $tz   = shift;
//       $self->{session}->timezone($tz) or return $self->_error('Failed to set timezone');
// }

// sub remap{
//       my $self = shift;
//       my $class = shift;

//       return $self->_error('class must be specified') unless $class;

//       $self->{globalclass} = $class;

//       return 1;
// }

// sub unmap{ undef $_[0]->{globalclass}; return 1 }
// sub DESTROY{ $_[0]->flush_handles }

}
