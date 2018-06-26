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
      assign_price_list_to_group(customer_group, price_list, row[KEY_FOR_PRISLISTA])
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

    def self.assign_price_list_to_group(group, price_list, code)
      unless price_list.present?
        Wm3PerfectaBridge::logger.info("Can not find pricelist. (#{code})")
        return
      end
      group.price_list = find_or_create_price_list(price_list[KEY_FOR_BETECKNING])
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
      new_prices = prices.map do |price|
        variant = store.variants.find_by(sku: price["Kod"])
        unless variant
          Wm3PerfectaBridge::logger.info("Can not find variant for price list. (#{price["Kod"]}, #{code})")
          next
        end
        # Get price for product in list
        new_price = Shop::Price.new(
          store_id: store.id,
          variant_id: variant.id
        )
        new_price.amount = calculated_price(price, variant)
        # Find staggering prices
        staggerings = Importer
          .select("staffling", {"Pris-id" => price["Pris-id"]})
        # Assign new staggering prices
        staggering_prices = staggerings.map do |staggering|
          Wm3PerfectaBridge::logger.info("Found staggered price. (#{price["Kod"]}, #{staggering["Pris exkl. moms"]})")
          new_price.staggered_prices.new(
            start_quantity: staggering["Stafflat antal"],
            amount: staggering["Pris exkl. moms"]
          )
        end
        # Set staggering prices
        new_price.staggered_prices = staggering_prices
        new_price
      end
      valid_new_prices = validated_prices(new_prices, price_list)
      return nil unless valid_new_prices.present?
      # Return price list if old and new prices are still equal
      return price_list unless validate_changes(valid_new_prices, price_list)
      # Destroy all prices and recreate them
      price_list.prices.destroy_all
      price_list.prices = valid_new_prices
      price_list.save
      new_prices_presentation = valid_new_prices.map do |p|
        [p.variant_id, p.amount.to_f, p.staggered_prices.map{|s| [s.start_quantity, s.amount.to_f]}]
      end
      Wm3PerfectaBridge::logger.info("Saved new prices. (#{price_list.name}, #{new_prices_presentation})")
      price_list
    end

    def self.calculated_price(price, variant)
      case price["Typ"]
      when "F"
        price["Pris"]
      when "R"
        variant.price.amount * ((100 - price["%"].to_f) / 100)
      else
        variant.price.amount
      end
    end

    def self.validated_prices(new_prices, price_list)
      return nil unless new_prices.compact.present?
      pr = new_prices.compact
      # Store only variant codes, used for checking after multiple variants
      variant_codes = pr.map(&:variant_id)
      # Log mutliple variants in same list
      variant_codes.select{|p| variant_codes.count(p) > 1 }.each do |v|
        Wm3PerfectaBridge::logger.info("#{v} has multiple prices in same list")
      end
      pr.uniq{|v| v.variant_id}
    end

    def self.validate_changes(new_prices, price_list)
      return false if new_prices.size < price_list.prices.size
      new_prices.compact.map do |new_price|
        validate_price_changes(new_price, price_list)
      end.flatten.include?(false)
    end

    def self.validate_price_changes(new_price, price_list)
      variant_price = price_list.prices.find do |price|
        price.variant_id == new_price.variant.id && price.amount == new_price.amount
      end
      return false unless variant_price
      return true if both_staggered_price_is_blank?(new_price, variant_price)
      return false if new_price.staggered_prices.size < variant_price.staggered_prices.size
      [true, new_price.staggered_prices.map do |new_staggered_price|
        variant_price.staggered_prices.find do |staggered_price|
          staggered_price.start_quantity == new_staggered_price.start_quantity &&
            staggered_price.amount == new_staggered_price.amount
        end.present?
      end]
    end

    def self.both_staggered_price_is_blank?(new_price, variant_price)
      new_price.staggered_prices.blank? == true &&
        variant_price.staggered_prices.blank? == true
    end
  end
end
