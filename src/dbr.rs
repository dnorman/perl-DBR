use std::cell::RefCell;
use perl_xs::{ IV, DataRef };

xs! {
    package DBR;

    sub new(ctx, class: String) {
        println!("new {:?}", class);
        let dbrbuilder = DBRBuilder::from_perl_kv(&mut ctx, 1);
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

#[derive(FromPerlKV,Debug)]
struct DBRBuilder {
    use_exceptions: bool,
    app:            Option<String>,
    #[perlxs(key = "-conf")]
    conf:           Option<String>,
    logpath:        Option<String>,
    loglevel:       Option<String>,
    #[perlxs(key = "-logger")]
    logger:         Option<String>,
    #[perlxs(key = "-admin")]
    admin:          bool,
    #[perlxs(key = "-fudge_tz")]
    fudge_tz:       bool,

}