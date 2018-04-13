module Wm3PerfectaBridge
  class CustomerMap < Map
    @customer = [
      {"company" => "Företag"},
      {"organisation_number" => "Organisationsnr"}
    ]

   @dynamic_field = [
     {"Företagskod" => "Företagskod"},
     {"Referens" => "Referens"}
   ]

   @address = [
     {"alternative_phone" => "Telefon 2"},
     {"company" => "Företag"},
     {"address1" => "Gatuadress"},
     {"email" => "E-postadress"},
     {"phone" => "Telefon"},
     {"zipcode" => "postadress"},
     {"city" => "adress"}
   ]

   @primary_account = [
     {"email" => "Anv Web"},
     {"alternative_phone" => "Telefon 2"},
     {"phone" => "Telefon"}
   ]

  end
end
