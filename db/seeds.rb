# This file should contain all the record creation needed to seed the database with its default values.
# The data can then be loaded with the rake db:seed (or created alongside the db with db:setup).

# -- Spree
unless Spree::Country.find_by_name 'Mexico'
  puts "[db:seed] Seeding Spree"
  #Spree::Core::Engine.load_seed if defined?(Spree::Core)
  Spree::Country.create!({"name"=>"Mexico", "iso3"=>"MEX", "iso"=>"MX", "iso_name"=>"MEXICO", "numcode"=>"484"}, :without_protection => true)
  zone = Spree::Zone.create!(:name => "Mexico", :description => "Mexico")
  zone.zone_members.create!(:zoneable => Spree::Country.find_by_name!("Mexico"))
  Spree::Role.create!(:name => "admin")
  Spree::Role.create!(:name => "user")

  Spree::Auth::Engine.load_seed if defined?(Spree::Auth)
end

# -- States
unless Spree::State.find_by_name 'CDMX'
  country = Spree::Country.find_by_name('Mexico')
  puts "[db:seed] Seeding states"

  [
   ['CDMX', 'CDMX']
  ].each do |state|
    Spree::State.create!({"name"=>state[0], "abbr"=>state[1], :country=>country}, :without_protection => true)
  end
end
