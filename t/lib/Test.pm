package t::lib::Test;

# Delete temporary files
sub clean {
	unlink( 'test-subject-db.sqlite' );
	unlink( 'test-config-db.sqlite'  );
}

# Clean up temporary test files both at the beginning and end of the
# test script.
BEGIN { clean() }
END   { clean() }

# A simplified connect function for the most common case
sub connect_ok {

}

1;
