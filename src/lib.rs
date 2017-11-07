#[macro_use]
extern crate perl_xs;
#[macro_use]
extern crate perl_sys;
#[macro_use]
extern crate perlxs_derive;

mod dbr;

xs! {
    bootstrap boot_DBR;
    use dbr;
}
