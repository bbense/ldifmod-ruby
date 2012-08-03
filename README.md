ldifmod-ruby
============


A script to duplicate the results of ldapmodify on a static ldiff file. ldifmod will read in ldiff change files and apply those mods to an given ldif file. It writes the result to stdout. I'm not sure it is a complete implementation of all the features of ldapmodify, but I have used it sucessfully to implement attribute adds and modifies. 