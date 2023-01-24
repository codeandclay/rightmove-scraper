# frozen_string_literal: true

require 'csv'
require 'json'
require 'nokogiri'
require 'open-uri'
require 'pry'

base_url = "https://www.rightmove.co.uk"
url = base_url +
      '/property-for-sale/find.html' \
      '?locationIdentifier=REGION%5E536' \
      '&radius=5.0' \
      '&propertyTypes=bungalow%2Cdetached%2Csemi-detached%2Cterraced' \
      '&mustHave=garden'

doc = Nokogiri::HTML(URI.open(url))

# Helper to extract JSON wrapped in <script> tags
def json_for(doc)
  JSON.parse(
    doc.xpath('//script[not(@src)]')[2].text.gsub('window.jsonModel = ', ''),
    symbolize_names: true
  )
end

# The results are paginated. We can construct the URL for each page from data
# within the JSON of the results page.
page_urls = json_for(doc).dig(:pagination, :options).map do |option|
  next url if option[:value].to_i.zero?

  "#{url}&index=#{option[:value]}"
end

# Get info of all properties
properties = page_urls.flat_map do |page_url|
  doc = Nokogiri::HTML(URI.open(page_url))

  json_for(doc)[:properties].map do |property|
    {
      id: property[:id],
      url: base_url + property[:propertyUrl],
      price: property.dig(:price, :amount),
      additional_price_info: property.dig(:price, :displayPrices).first[:displayPriceQualifier],
      bedrooms: property[:bedrooms],
      updated_at: property.dig(:listingUpdate, :listingUpdateDate),
      update_reason: property.dig(:listingUpdate, :listingUpdateReason),
      is_auction: property[:auction],
      scraped_at: Time.new
    }
  end
end

# Now output that data
CSV.open('./scraped_properties.csv', 'w', write_headers: true, headers: properties.first.keys.map(&:to_s)) do |csv|
  properties.each { |property| csv << property.values }
end
