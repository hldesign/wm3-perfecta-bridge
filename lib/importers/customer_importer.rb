module Wm3PerfectaBridge
  class CustomerImport < Importer

    KEY_FOR_FORETAGSKOD = "Företagskod"
    KEY_FOR_PRISLISTEID = "PrislisteID"
    KEY_FOR_PRISLISTA = "Prislista"
    KEY_FOR_BETECKNING = "Beteckning"
    KEY_FOR_STANDARDAVTAL = "Standardavtal"
    KEY_FOR_AVTALSKOD = "Avtalskod"
    KEY_FOR_ANV_WEB = "Anv Web"

    def self.type
      "customer"
    end

    def self.import(row)
      # return if "Anv Web" is not defined
      unless row["Anv Web"]
        Wm3PerfectaBridge::logger.info("#{row["Företagskod"]} misses Anv Web, customer ignored")
        return
      end
      # find customer
      customer = store.customers.joins(:customer_accounts)
        .where(shop_customer_accounts: {
          email: row[KEY_FOR_ANV_WEB],
          primary_account: true
      }).first
      # initialize new customer if customer is not defined
      unless customer
        customer = store.customers.new
        # Customer should skip registration message
        customer.primary_account.skip_registration_message = true
        # Set temporary password
        customer.primary_account.password = SecureRandom.hex(10)
      end
      # create new customer group
      customer_group = store
        .customer_groups
        .find_or_create_by(name: row["Företagskod"])
      # Set customer to customer group
      customer.customer_group = customer_group
      # Assign customer properties
      assign_attributes(row, customer)
      # Find or create price list
      price_list = Importer
        .find("prislista", {KEY_FOR_PRISLISTEID => row[KEY_FOR_PRISLISTA]})
      customer_group
        .price_list = find_or_create_price_list(price_list[KEY_FOR_BETECKNING])
      # Find or create discount list or campaign list
      special_list = add_campaign_or_discount_list(row[KEY_FOR_FORETAGSKOD])
      if special_list.is_a? Shop::DiscountList
        customer_group.discount_list = special_list
      elsif list.is_a? Shop::Campaign
        customer_group.campaign = special_list
      end
      # Save customer and Customer group
      if customer.save && customer_group.save
        Wm3PerfectaBridge::logger.info("Successfully saved customer #{row["Företagskod"]}")
      else
        Wm3PerfectaBridge::logger.info("Unable to save #{row["Företagskod"]}")
      end
    end

    private

    def self.assign_attributes(row, customer)
      # Assign attributes for active records, CustomerMap.rb for keys
      # (custoomer, primary account and address)

      # Split and merge Referens with hash keys
      row.merge(row["Referens"].split.each_with_index
        .map{|v, i| {["namn", "last_name"][i] => v }}
        .reduce({}, :merge))

      # Split and merge postal code with hash keys
      len = row["Gatupostadress"].length
      row = row.merge({"postadress" => row["Gatupostadress"][0..5]})
      row = row.merge({"adress" => row["Gatupostadress"][7..len]})

      # Get default ship address for attribute assignement
      default_ship_address = customer.addresses.find_or_create_by(
        default_ship_address: true,
        country: country
      )

      # Assign attributes
      ["customer", "primary_account", "address"].each do |type|
        CustomerMap.each(type) do |attr, value|
          case type
          when "customer"
            customer.send("#{attr}=", row[value])
          when "primary_account"
            customer.primary_account.send("#{attr}=", row[value])
          when "address"
            default_ship_address.send("#{attr}=", row[value])
          end
        end
      end
      customer
    end

    def self.find_or_create_campaign(name)
      return unless code.present?
      row = Importer.find(
        "avtalspriser", {KEY_FOR_AVTALSKOD => code}
      )
      list = store.campaigns.find_by(
        name: row[KEY_FOR_BETECKNING]
      )
      unless list
        list = store.campaigns.new({
          name: row[KEY_FOR_BETECKNING],
          start_at: row["Fr datum"],
          end_at: row["Till datum"]
        })
        list.save
      end
      list
    end

    def self.find_or_create_discount_list(code)
      return unless code.present?
      row = Importer.find(
        "avtalspriser", {KEY_FOR_AVTALSKOD => code}
      )
      store.discount_lists
        .find_or_create_by({ name: row[KEY_FOR_BETECKNING] })
    end

    def self.campaign_or_discount_list(campaign, code)
      # If campaign is true, create a campaign list, else discount list.
      campaign ? find_or_create_campaign(code) : find_or_create_discount_list(code)
    end

    def self.add_campaign_or_discount_list(code)
      return nil unless code.present?
      prices = Importer.select("avtalspriser", {KEY_FOR_AVTALSKOD => code})
      campaign = prices.map{|g| g["Kampanj"]}.uniq
      if campaign.length > 2
      end
      list = campaign_or_discount_list(campaign.first == "True", code)
      new_prices = prices.map do |price|
        product = store.products.find_by(skus: price["Kod"])
        # Get price for product in list
        new_price = list.prices.new(
          store_id: store.id,
          variant_id: product.master.id,
          amount: price["Pris"]
        )
        # Find staggering prices
        staggerings = Importer
          .select("staffling", {"Pris-id" => price["Pris-id"]})
        # Assign new staggering prices
        staggering_prices = staggerings.map do |staggering|
          new_price.staggered_prices.new(
            start_quantity: staggering["Stafflat antal"],
            amount: staggering["Totalt pris"]
          )
        end
        # Set staggering prices
        new_price.staggered_prices = staggering_prices
        new_price
      end
      list.prices = new_prices
      list.save
      list
    end
  end
end
