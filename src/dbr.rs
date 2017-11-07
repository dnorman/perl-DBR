use std::cell::RefCell;
use perl_xs::{ IV, DataRef };
use perl_xs::convert::{FromKeyValueStack};
use perl_xs::context::Context;

xs! {
    package DBR;

    sub new(ctx, class: String) {
        println!("new {:?}", class);
        let dbrbuilder = DBRBuilder::from_kv_stack(&mut ctx, 1);
        println!("DBRBuilder {:?}", dbrbuilder);

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
    logger:         Option<String>,
    admin:          bool,
    fudge_tz:       bool,

}

impl FromKeyValueStack for DBRBuilder {

    fn from_kv_stack ( ctx: &mut Context, offset: isize ) -> Self {

        let mut logger : Option<String> = None;
        let mut conf   : Option<String> = None;
        let mut admin    = false;
        let mut fudge_tz = false;

        let mut i = offset;

        while let Some(sv_res) = ctx.st_try_fetch::<String>(i) {
            match sv_res {
                Ok(key) => { 
                    match &*key {
                        "-logger" => {
                            let s_res = ctx.st_try_fetch::<String>(i+1).expect("no argument provided for parameter \"{}\"");
                            let v = s_res.expect("parameter {} unable to be interpreted as a string");
                            logger = Some( v );
                        }
                        "-conf"   => {
                            let s_res = ctx.st_try_fetch::<String>(i+1).expect("no argument provided for parameter \"{}\"");
                            let v = s_res.expect("parameter {} unable to be interpreted as a string");
                            conf = Some( v );
                        }
                        "-admin" => {
                            let s_res = ctx.st_try_fetch::<bool>(i+1).expect("no argument provided for parameter \"{}\"");
                            let v = s_res.expect("parameter {} unable to be interpreted as a bool");
                            admin = v;
                        }
                        "-fudge_tz" => {
                            let s_res = ctx.st_try_fetch::<bool>(i+1).expect("no argument provided for parameter \"{}\"");
                            let v = s_res.expect("parameter {} unable to be interpreted as a bool");
                            fudge_tz = v;
                        },
                        _ => {
                            panic!("unsupported parameter {}",key);
                        }
                    }
                },
                Err(e) => {
                    panic!("paramter key is not a string {}", e);
                }
            }

            i += 2;
        }

        Self{
            use_exceptions: true,
            app:            None,
            conf:           conf,
            logpath:        None,
            loglevel:       None,
            logger:         logger,
            admin:          admin,
            fudge_tz:       fudge_tz,
        }
    }
}