module Wm3PerfectaBridge
  class Reporter < ActionMailer::Base
    TYPES = ['prices']

    def self.export(type)

      raise "Unvalid export type" unless TYPES.include?(type)

      @store = Wm3PerfectaBridge::Importer.store

      csv_files = []
      self.send(type).each_slice(50000) do |chunks|
        csv_files << CSV.generate do |csv|
          chunks.each do |data|
            csv << data
          end
        end
      end

      if Rails.env.development?
        csv_files.each_with_index do |file, index|
          save_path = ::Pathname.new("tmp/perfecta_export")
          save_path.mkpath
          save_name = format(
            "#{type}_export-%<time>s(#{index}).csv",
            time: Time.now.to_s

          )
          (save_path + save_name).open('w') {|file| file.write(file)}
        end
      else
      end
      Wm3PerfectaBridge::Mailer.send_export(csv_files, type, @store.email).deliver
    end

    def self.prices
      result = []
      currency_id = @store.default_currency.id
      plucks = [
        "shop_customers.id",
        "shop_customer_groups.price_list_id",
        "shop_customer_groups.discount_list_id",
        "shop_customer_groups.name",
        "shop_customer_accounts.email"
      ]

      customers.pluck(*plucks).each do |columns|
        @store.variants.where(for_sale: true).each do |variant|
          begin
            price = variant.price_for(
              currency_id,
              columns[1], # group.price_list_id
              columns[2], # group.discount_list_id
              columns[0]  # customer.id
            ).final_amount.to_f
            result << [columns[3], columns[4], variant.name, "#{price} :-"]
          rescue
            result << [columns[3], columns[4], variant.name, "unknown"]
          end
        end
      end
      result
    end

    private

    def self.customers
      @store
        .customers
        .joins(:customer_group, :customer_accounts)
        .where("shop_customer_accounts.verified IS true")
        .order("shop_customer_groups.name")
    end
  end
end
