use std::cell::RefCell;
use perl_xs::{ IV, DataRef };
use perl_xs::convert::{FromKeyValueStack};
use perl_xs::context::Context;
use perlxs_derive::FromKeyValueStack;

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

#[derive(Debug, FromKeyValueStack)]
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