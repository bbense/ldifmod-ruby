#!/usr/bin/ruby

USAGE = <<EOF

ldifmod will read in ldiff change files and apply those mods to an given ldif file.
It writes the result to stdout. 

--ldif <filename> ldif input file with "standard" dn records. 

--mods <filename> ldif modify file, see ldap_modify man page for format.


Examples. 

ldifmod.rb --ldif passwd.ldif --mods g-scs.ldif --mods babar.ldif 
                          
EOF

require 'ldap'
require 'ldap/ldif'

class LDIFdb
  attr :entries
  def initialize(arg)
    @file = arg
    @entries = LDAP::LDIF.parse_file(arg)
    # Turn entries into dn hash of LDAP::Entry ???
    @dnhash = nil
  end

  def each
    @entries.each { |x| yield x }
  end

  # Retrieve entry with specific dn
  def getDN (dn)
    if ( @dnhash.nil? ) then
      @dnhash = Hash.new
      self.each do |entry|
        @dnhash[entry.dn] = entry
      end
    end
    @dnhash[dn]
  end

  # Go through a list of records that are mods and apply any that match the DN.

  def apply_mods( modsArray )

    compact = false

    modsArray.each do |record|
      entry =  self.getDN(record.dn)
      case record.change_type & ~LDAP::LDAP_MOD_BVALUES

      when LDAP::LDAP_MOD_ADD
        # self.add_entry(record) record.dn should not already exist.

      when LDAP::LDAP_MOD_DELETE # self = nil?
        unless ( entry.nil? ) then
          entry = nil
          compact = true
        end

      when LDAP::LDAP_MOD_REPLACE
        # change_type modify is mapped to replace
        entry.apply_mod(record) unless ( entry.nil? )
      end
    end

    @entries.compact! if compact # Remove all nil objects
  end

  def write
    @entries.each do |entry|
      print entry.to_s
      print "\n"
    end
  end

end

class LDAP::Record
  # 
  # changetype: modify can add, replace, or remove attributes or attribute values in an entry. 
  # When you specify changetype: modify, you must also provide a change operation to indicate 
  # how the entry is to be modified. Change operations can be as follows:
  # 
  # add:attribute
  # 
  # Adds the specified attribute or attribute value. If the attribute type does not currently exist
  # for the entry, then the attribute and its corresponding value are created. If the attribute type 
  # already exists for the entry, then the specified attribute value is added to the existing value. 
  # If the particular attribute value already exists for the entry, then the operation fails, and 
  # the server returns an error.
  #
  # replace:attribute
  # 
  # The specified values are used to entirely replace the attribute's values. If the attribute does
  # not already exist, it is created. If no replacement value is specified for the attribute, 
  # the attribute is deleted.
  #
  # delete:attribute
  # 
  # The specified attribute is deleted. If more than one value of an attribute exists for the entry, 
  # then all values of the attribute are deleted in the entry. To delete just one of many attribute 
  # values, specify the attribute and associated value on the line following the delete change operation.
  #
  def apply_mod(modrec)
    modrec.mods.each do |type,attribute|
      # Should case on type here, but just assume all adds for testing. Fix This. 
      case type
      when LDAP::LDAP_MOD_ADD
        attribute.keys.each do |key|
          self.attrs[key] = [] if self.attrs[key].nil?
          self.attrs[key].push( attribute[key] )
        end
      when LDAP::LDAP_MOD_REPLACE
        attribute.keys.each do |key|
          self.attrs[key] = []
          self.attrs[key].push( attribute[key] )
        end
      when LDAP::LDAP_MOD_DELETE
        # This deletes all values of attribute. 
        attribute.keys.each do |key|
          self.attrs[key] = nil
        end

      else
        # Raise error unknown change type. 
        raise ArgumentError, "Unknown modify type #{ type }"
      end

    end
  end

  def to_s
    tmp = format("dn: %s\n",self.dn)
    # Need to print these in a defined order. 
    order = self.attrs.keys.sort
    order.each do |key|
      self.attrs[key].each do |value|
        tmp << format("%s: %s\n",key,value)
      end
    end
    # self.attrs.each do |key,values|
    #   values.each do |value|
    #     tmp << format("%s: %s\n",key,value)
    #   end
    # end
    tmp
  end

end

require 'getoptlong'

opts = GetoptLong.new(
[ "--help", "-h" , GetoptLong::NO_ARGUMENT],
[ "--debug", "-d", GetoptLong::NO_ARGUMENT],
['--ldif', '-l', GetoptLong::REQUIRED_ARGUMENT ],
['--mods', '-m', GetoptLong::REQUIRED_ARGUMENT ]


)

modsFiles = []
ldif_file = nil
begin
  opts.each do |opt, arg|
    case opt
    when "--help"
      print USAGE
      exit

    when "--debug"
      $DEBUG = true
    when "--ldif"
      ldif_file = arg
      raise "#{ ldif_file } not readable" unless ( File.readable?(ldif_file) )
    when "--mods"
      raise "#{ arg } file not readable" unless ( File.readable?(arg) )
      modsFiles.push(arg)
    end
  end

rescue => err
  print "#{ err.to_s }\n #{ USAGE }"
  exit
end

if ldif_file.nil? then
  print "No ldif_file in command line\n" ;
  exit
end

records = LDIFdb.new(ldif_file)

modsFiles.each do |mfile|
  mods = LDIFdb.new(mfile)
  records.apply_mods(mods)
end

records.write
