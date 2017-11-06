#[macro_use]
extern crate perl_xs;
#[macro_use]
extern crate perl_sys;

mod dbr;

xs! {
    bootstrap boot_DBR;
    use dbr;
}
