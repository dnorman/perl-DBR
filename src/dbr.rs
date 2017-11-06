use std::cell::RefCell;
use perl_xs::{ IV, AV, SV, DataRef };

xs! {
    package DBR;

    sub new(ctx, class: String) {
        //, initial: AV)

        for i in 0.. {
            let string : Option<SV> = ctx.st_fetch(i);
            match string {
                None    => break,
                Some(s) =>  println!("{}", s.to_string().unwrap()),
            }
        }

        ctx.new_sv_with_data(RefCell::new(123)).bless(&class)
    }

    sub get(_ctx, this: DataRef<RefCell<IV>>) {
        return *this.borrow();
    }

    sub inc(_ctx, this: DataRef<RefCell<IV>>) {
        *this.borrow_mut() += 1;
    }
}
