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
      @row = row
      # return if "Anv Web" is not defined
      unless row["Anv Web"]
        raise ArgumentError, "#{row[KEY_FOR_FORETAGSKOD]} misses Anv Web, customer ignored"
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
      # Set customer to customer group
      customer.customer_group = customer_group
      # Assign customer properties
      assign_attributes(row, customer)
      # Find or create price list
      price_list = Importer
        .find("prislista", {KEY_FOR_PRISLISTEID => row[KEY_FOR_PRISLISTA]})
      assign_price_list_to_group(price_list, row[KEY_FOR_PRISLISTA])
      # Find or create discount list or campaign list
      special_list = add_campaign_or_discount_list(row[KEY_FOR_FORETAGSKOD])
      if special_list.is_a? Shop::DiscountList
        customer_group.discount_list = special_list
      elsif special_list.is_a? Shop::Campaign
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

    def self.customer_group
      if @customer_group.try(:name) == @row["Företagskod"]
        @customer_group
      else
        @customer_group = store.customer_groups
          .find_or_create_by(name: @row["Företagskod"])
      end
    end

    def self.assign_price_list_to_group(price_list, code)
      unless price_list.present?
        Wm3PerfectaBridge::logger.info("Can not find pricelist. (#{code})")
        return
      end
      customer_group.price_list = find_or_create_price_list(price_list[KEY_FOR_BETECKNING])
    end

    def self.assign_attributes(row, customer)
      # Assign attributes for active records, CustomerMap.rb for keys
      # (customer, primary_account and address)

      # Split and merge Referens with hash keys
      if row["Referens"].present? && row["Gatupostadress"].present?
        row.merge(row["Referens"].split.each_with_index
          .map{|v, i| {["namn", "last_name"][i] => v }}
          .reduce({}, :merge))

        # Split and merge postal code with hash keys
        len = row["Gatupostadress"].length
        row = row.merge({"postadress" => row["Gatupostadress"][0..5]})
        row = row.merge({"adress" => row["Gatupostadress"][7..len]})
      else
        Wm3PerfectaBridge.logger.info("Can not find columns. (#{row[KEY_FOR_FORETAGSKOD]}, #{row['Referens']}, #{row['Gatupostadress']})")
      end

      # Get default ship address for attribute assignement
      default_ship_address = customer.addresses.find_or_initialize_by(
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

    def self.find_or_create_campaign(code)
      return unless code.present?
      row = Importer.find(
        "avtalspriser", {KEY_FOR_AVTALSKOD => code}
      )
      return unless row.present?
      store.campaigns.find_or_create_by(name: row[KEY_FOR_FORETAGSKOD]) do |l|
        l.prices_include_tax = false
        l.start_at = row["Fr datum"]
        l.end_at = row["Till datum"]
      end
    end

    def self.find_or_create_discount_list(code)
      return unless code.present?
      row = Importer.find(
        "avtalspriser", {KEY_FOR_AVTALSKOD => code}
      )
      return unless row.present?
      h = {name: row[KEY_FOR_AVTALSKOD]}
      store.discount_lists.find_or_create_by(h) do |l|
        l.prices_include_tax = false
      end
    end

    def self.campaign_or_discount_list(campaign, code)
      # If campaign is true, create a campaign list, else discount list.
      campaign ? find_or_create_campaign(code) : find_or_create_discount_list(code)
    end

    def self.add_campaign_or_discount_list(code)
      return nil unless code.present?
      prices = Importer.select("avtalspriser", {KEY_FOR_AVTALSKOD => code})
      campaign = prices.map{|g| g["Kampanj"]}.uniq
      price_list = campaign_or_discount_list(campaign.first == "True", code)
      unless price_list.present?
        Wm3PerfectaBridge::logger.info("Could not create customer price list. (#{code})")
        return nil
      end
      price_codes = prices.map{|p| p["Kod"]}
      price_list.prices.each do |price|
        price.destroy if !price_codes.include?(price.variant.sku)
      end
      prices.each do |price|
        variant = store.variants.find_by(sku: price["Kod"])
        unless variant
          Wm3PerfectaBridge::logger.info("Can not find variant for price list. (#{price["Kod"]}, #{code})")
          next
        end
        old_price = price_list.prices.find_by(variant_id: variant.id)
        new_price = compute_price(price, variant, price_list.prices.new(variant_id: variant.id))
        
        if old_price&.final_amount != new_price.final_amount
          old_price&.destroy
          new_price.save
        end

        # Find staggering prices
        staggerings = Importer
          .select("staffling", {"Pris-id" => price["Pris-id"]})

        staggerings_quantities = staggerings.map{|s| s["Stafflat antal"].to_i}
        new_price.staggered_prices.each do |staggered_price|
          staggered_price.destroy if !staggerings_quantities.include?(staggered_price.start_quantity)
        end

        staggerings.each do |staggered_price|
          s = new_price.staggered_prices.find_or_initialize_by(
            start_quantity: staggered_price["Stafflat antal"]
          )
          s.amount = staggered_price["Pris exkl. moms"]
          s.save
        end
      end

      price_list
    end

    def self.compute_price(price, variant, wm3_price)
      case price["Typ"]
      when "F"
        wm3_price.amount = price["Pris"]
      when "R"
        wm3_price.amount = variant.price.amount
        wm3_price.discount = price["%"]
      else
        wm3_price.amount = variant.price.amount
        wm3_price.discount = customer_group
          &.price_list
          &.prices
          &.find_by(variant_id: variant.id)
          &.discount || 0
      end
      wm3_price
    end
  end
end
