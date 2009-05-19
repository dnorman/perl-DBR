AC_DEFUN([LE_MSG_CONFIGURE_START],
[
   AC_MSG_RESULT
   AC_MSG_RESULT([Configuring DBR.])
   AC_MSG_RESULT
])

AC_DEFUN([LE_MSG_CONFIGURE_END],
[
   AC_MSG_RESULT
   AC_MSG_RESULT([Type 'make install' to install the library.])
   AC_MSG_RESULT
])

AC_DEFUN([AC_PROG_PERL_VERSION],[dnl
# Make sure we have perl
if test -z "$PERL"; then
AC_CHECK_PROG(PERL,perl,perl)
fi

# Check if version of Perl is sufficient
ac_perl_version="$1"

if test "x$PERL" != "x"; then
  AC_MSG_CHECKING(for perl >= $ac_perl_version)
  # NB: It would be nice to log the error if there is one, but we cannot rely
  # on autoconf internals
  $PERL -e "use $ac_perl_version;" > /dev/null 2>&1
  if test $? -ne 0; then
    AC_MSG_RESULT(no);
    $3
  else
    AC_MSG_RESULT(ok);
    $2
  fi
else
  AC_MSG_WARN(could not find perl)
fi
])dnl

AC_DEFUN([AC_PERL_GET_VERSION],[dnl

   # is PERL already defined?
   if test -z "$PERL"; then
      AC_CHECK_PROG(PERL,perl,perl)
   fi

   AC_MSG_CHECKING(actual perl version)

   opt_perl_version=`$PERL -V:version | sed "s/.*'\(.*\)';/\1/g"`
   
   if test "x$opt_perl_version" != "x"
      then
         PERL_VERSION="$opt_perl_version"
         AC_SUBST(PERL_VERSION)dnl
         AC_MSG_RESULT([$PERL_VERSION])
   fi

])dnl
           

AC_DEFUN([AC_PERL_MODULE_INSTALL_PATH],[dnl

   # is PERL already defined?
   if test -z "$PERL"; then
      AC_CHECK_PROG(PERL,perl,perl)
   fi

   # is PERL_VERSION already defined?
   if test -z "$PERL_VERSION"; then
      AC_PERL_GET_VERSION
   fi

   # check and see if it's specified to 'configure'
   AC_ARG_WITH(perl-install-path,
               AC_HELP_STRING([--with-perl-install-path],
                              [install path (def: system's site-perl)]),
               [opt_perl_instpath="$withval"],
               [opt_perl_instpath="not_set"])dnl
   
   AC_MSG_CHECKING(the preferred install location)
   case "$opt_perl_instpath" in
      not_set ) 
         opt_perl_instpath=`$PERL -V:sitelib | sed "s/.*'\(.*\)';/\1/g"` dnl
         INSTALL_PATH="$opt_perl_instpath" dnl
         ;;
      * ) dnl
         INSTALL_PATH="$opt_perl_instpath"
         ;;
   esac

   AC_SUBST(INSTALL_PATH)dnl
   AC_MSG_RESULT([$INSTALL_PATH])
])dnl
