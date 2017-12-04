#[macro_use]
extern crate perl_xs;
#[macro_use]
extern crate perl_sys;
#[macro_use]
extern crate perlxs_derive;

extern crate regex;
extern crate core;

mod context;
mod config;
mod error;
mod util;
mod adapter;

use context::Context;

mod wrapper;

xs! {
    bootstrap boot_DBR;
    use wrapper::dbr;
}
