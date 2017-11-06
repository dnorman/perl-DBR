use std::cell::RefCell;
use perl_xs::{ IV, AV, SV, DataRef };
use perl_xs::convert::{FromSV,FromKeyValueStack};
use perl_xs::context::Context;

xs! {
    package DBR;

    sub new(ctx, class: String) {
        //, initial: AV)

        let dbrbuilder = DBRBuilder::from_st(&ctx);

        ctx.new_sv_with_data(RefCell::new(123)).bless(&class)
    }

    sub get(_ctx, this: DataRef<RefCell<IV>>) {
        return *this.borrow();
    }

    sub inc(_ctx, this: DataRef<RefCell<IV>>) {
        *this.borrow_mut() += 1;
    }
}

//FromKeyValueStack, 
#[derive(Debug)]
struct DBRBuilder {
    use_exceptions: bool,
    app:            Option<String>,
    conf:           Option<String>,
    logpath:        Option<String>,
    loglevel:       Option<String>,

}

impl FromKeyValueStack for DBRBuilder {

    fn from_kv_stack ( ctx: Context ) -> Self {

        let mut logger : Option<String> = None;
        let mut conf   : Option<String> = None;
        let mut admin    = false;
        let mut fudge_tz = false;

        let mut i = 0;

        while let Some(sv) = ctx.st_fetch(i) {
            match sv {
                String::from("-logger") => {
                    logger = Some( ctx.st_fetch(i+1).expect("no argument provided for parameter").to_string() )
                }
                String::from("-conf")   => {
                    conf   = Some( ctx.st_fetch(i+1).expect("no argument provided for parameter").to_string() )
                }
                String::from("-admin") => {
                    admin  = ctx.st_fetch(i+1).expect("no argument provided for parameter")
                }
                String::from("-fudge_tz") => {
                    fudge_tz  = ctx.st_fetch(i+1).expect("no argument provided for parameter")
                }
            }

            i += 2;
        }

        Self{
            use_exceptions: true,
            app:            None,
            conf:           conf.expect("must specify conf"),
            logpath:        None,
            loglevel:       None,
        }
    }
}