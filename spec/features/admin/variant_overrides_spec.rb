require 'spec_helper'

feature %q{
  As an Administrator
  With products I can add to order cycles
  I want to override the stock level and price of those products
  Without affecting other hubs that share the same products
}, js: true do
  include AuthenticationWorkflow
  include WebHelper

  let!(:hub) { create(:distributor_enterprise) }
  let!(:hub2) { create(:distributor_enterprise) }
  let!(:hub3) { create(:distributor_enterprise) }
  let!(:producer) { create(:supplier_enterprise) }
  let!(:er1) { create(:enterprise_relationship, parent: hub, child: producer,
                      permissions_list: [:add_to_order_cycle]) }

  context "as an enterprise user" do
    let(:user) { create_enterprise_user enterprises: [hub2, producer] }
    before { quick_login_as user }

    describe "selecting a hub" do
      it "displays a list of hub choices" do
        visit '/admin/variant_overrides'

        page.should have_select2 'hub_id', options: ['', hub.name, hub2.name]
      end
    end

    context "when a hub is selected" do
      let!(:product) { create(:simple_product, supplier: producer, variant_unit: 'weight', variant_unit_scale: 1) }
      let!(:variant) { create(:variant, product: product, unit_value: 1, price: 1.23, on_hand: 12) }

      let!(:producer_related) { create(:supplier_enterprise) }
      let!(:product_related) { create(:simple_product, supplier: producer_related) }
      let!(:variant_related) { create(:variant, product: product_related, unit_value: 2, price: 2.34, on_hand: 23) }
      let!(:er2) { create(:enterprise_relationship, parent: producer_related, child: hub,
                          permissions_list: [:create_variant_overrides]) }

      let!(:producer_unrelated) { create(:supplier_enterprise) }
      let!(:product_unrelated) { create(:simple_product, supplier: producer_unrelated) }


      before do
        # Remove 'S' option value
        variant.option_values.first.destroy
      end

      context "with no overrides" do
        before do
          visit '/admin/variant_overrides'
          select2_select hub.name, from: 'hub_id'
        end

        it "displays the list of products with variants" do
          page.should have_table_row ["PRODUCER", "PRODUCT", "PRICE", "ON HAND"]
          page.should have_table_row [producer.name, product.name, '', '']
          page.should have_input "variant-overrides-#{variant.id}-price", placeholder: '1.23'
          page.should have_input "variant-overrides-#{variant.id}-count_on_hand", placeholder: '12'

          page.should have_table_row [producer_related.name, product_related.name, '', '']
          page.should have_input "variant-overrides-#{variant_related.id}-price", placeholder: '2.34'
          page.should have_input "variant-overrides-#{variant_related.id}-count_on_hand", placeholder: '23'

          # filters the products to those the hub can override
          page.should_not have_content producer_unrelated.name
          page.should_not have_content product_unrelated.name

          # Filters based on the producer select filter
          expect(page).to have_selector "#v_#{variant.id}"
          expect(page).to have_selector "#v_#{variant_related.id}"
          select2_select producer.name, from: 'producer_filter'
          expect(page).to have_selector "#v_#{variant.id}"
          expect(page).to_not have_selector "#v_#{variant_related.id}"
          select2_select 'All', from: 'producer_filter'

          # Filters based on the quick search box
          expect(page).to have_selector "#v_#{variant.id}"
          expect(page).to have_selector "#v_#{variant_related.id}"
          fill_in 'query', with: product.name
          expect(page).to have_selector "#v_#{variant.id}"
          expect(page).to_not have_selector "#v_#{variant_related.id}"
          fill_in 'query', with: ''

          # Clears the filters
          expect(page).to have_selector "#v_#{variant.id}"
          expect(page).to have_selector "#v_#{variant_related.id}"
          select2_select producer.name, from: 'producer_filter'
          fill_in 'query', with: product_related.name
          expect(page).to_not have_selector "#v_#{variant.id}"
          expect(page).to_not have_selector "#v_#{variant_related.id}"
          click_button 'Clear All'
          expect(page).to have_selector "#v_#{variant.id}"
          expect(page).to have_selector "#v_#{variant_related.id}"
        end

        it "creates new overrides" do
          first("div#columns-dropdown", :text => "COLUMNS").click
          first("div#columns-dropdown div.menu div.menu_item", text: "SKU").click
          first("div#columns-dropdown div.menu div.menu_item", text: "On Demand").click
          first("div#columns-dropdown", :text => "COLUMNS").click

          fill_in "variant-overrides-#{variant.id}-sku", with: 'NEWSKU'
          fill_in "variant-overrides-#{variant.id}-price", with: '777.77'
          fill_in "variant-overrides-#{variant.id}-count_on_hand", with: '123'
          check "variant-overrides-#{variant.id}-on_demand"
          page.should have_content "Changes to one override remain unsaved."

          expect do
            click_button 'Save Changes'
            page.should have_content "Changes saved."
          end.to change(VariantOverride, :count).by(1)

          vo = VariantOverride.last
          vo.variant_id.should == variant.id
          vo.hub_id.should == hub.id
          vo.sku.should == "NEWSKU"
          vo.price.should == 777.77
          vo.count_on_hand.should == 123
          vo.on_demand.should == true
        end

        describe "creating and then updating the new override" do
          it "updates the same override instead of creating a duplicate" do
            # When I create a new override
            fill_in "variant-overrides-#{variant.id}-price", with: '777.77'
            fill_in "variant-overrides-#{variant.id}-count_on_hand", with: '123'
            page.should have_content "Changes to one override remain unsaved."

            expect do
              click_button 'Save Changes'
              page.should have_content "Changes saved."
            end.to change(VariantOverride, :count).by(1)

            # And I update its settings without reloading the page
            fill_in "variant-overrides-#{variant.id}-price", with: '111.11'
            fill_in "variant-overrides-#{variant.id}-count_on_hand", with: '111'
            page.should have_content "Changes to one override remain unsaved."

            # Then I shouldn't see a new override
            expect do
              click_button 'Save Changes'
              page.should have_content "Changes saved."
            end.to change(VariantOverride, :count).by(0)

            # And the override should be updated
            vo = VariantOverride.last
            vo.variant_id.should == variant.id
            vo.hub_id.should == hub.id
            vo.price.should == 111.11
            vo.count_on_hand.should == 111
          end
        end

        it "displays an error when unauthorised to access the page" do
          fill_in "variant-overrides-#{variant.id}-price", with: '777.77'
          fill_in "variant-overrides-#{variant.id}-count_on_hand", with: '123'
          page.should have_content "Changes to one override remain unsaved."

          user.enterprises.clear

          expect do
            click_button 'Save Changes'
            page.should have_content "I couldn't get authorisation to save those changes, so they remain unsaved."
          end.to change(VariantOverride, :count).by(0)
        end

        it "displays an error when unauthorised to update a particular override" do
          fill_in "variant-overrides-#{variant_related.id}-price", with: '777.77'
          fill_in "variant-overrides-#{variant_related.id}-count_on_hand", with: '123'
          page.should have_content "Changes to one override remain unsaved."

          er2.destroy

          expect do
            click_button 'Save Changes'
            page.should have_content "I couldn't get authorisation to save those changes, so they remain unsaved."
          end.to change(VariantOverride, :count).by(0)
        end
      end

      context "with overrides" do
        let!(:vo) { create(:variant_override, variant: variant, hub: hub, price: 77.77, count_on_hand: 11111, default_stock: 1000, resettable: true) }
        let!(:vo_no_auth) { create(:variant_override, variant: variant, hub: hub3, price: 1, count_on_hand: 2) }
        let!(:product2) { create(:simple_product, supplier: producer, variant_unit: 'weight', variant_unit_scale: 1) }
        let!(:variant2) { create(:variant, product: product2, unit_value: 8, price: 1.00, on_hand: 12) }
        let!(:vo_no_reset) { create(:variant_override, variant: variant2, hub: hub, price: 3.99, count_on_hand: 40, default_stock: 100, resettable: false) }
        let!(:variant3) { create(:variant, product: product, unit_value: 2, price: 5.00, on_hand: 6) }
        let!(:vo3) { create(:variant_override, variant: variant3, hub: hub, price: 6, count_on_hand: 7, sku: "SOMESKU", default_stock: 100, resettable: false) }

        before do
          visit '/admin/variant_overrides'
          select2_select hub.name, from: 'hub_id'
        end

        it "product values are affected by overrides" do
          page.should have_input "variant-overrides-#{variant.id}-price", with: '77.77', placeholder: '1.23'
          page.should have_input "variant-overrides-#{variant.id}-count_on_hand", with: '11111', placeholder: '12'
        end

        it "updates existing overrides" do
          fill_in "variant-overrides-#{variant.id}-price", with: '22.22'
          fill_in "variant-overrides-#{variant.id}-count_on_hand", with: '8888'
          page.should have_content "Changes to one override remain unsaved."

          expect do
            click_button 'Save Changes'
            page.should have_content "Changes saved."
          end.to change(VariantOverride, :count).by(0)

          vo.reload
          vo.variant_id.should == variant.id
          vo.hub_id.should == hub.id
          vo.price.should == 22.22
          vo.count_on_hand.should == 8888
        end

        # Any new fields added to the VO model need to be added to this test
        it "deletes overrides when values are cleared" do
          first("div#columns-dropdown", :text => "COLUMNS").click
          first("div#columns-dropdown div.menu div.menu_item", text: "On Demand").click
          first("div#columns-dropdown div.menu div.menu_item", text: "Reset Stock Level").click
          first("div#columns-dropdown", :text => "COLUMNS").click

          # Clearing values manually
          fill_in "variant-overrides-#{variant.id}-price", with: ''
          fill_in "variant-overrides-#{variant.id}-count_on_hand", with: ''
          fill_in "variant-overrides-#{variant.id}-default_stock", with: ''
          page.uncheck "variant-overrides-#{variant.id}-resettable"
          page.should have_content "Changes to one override remain unsaved."

          # Clearing values by 'inheriting'
          first("div#columns-dropdown", :text => "COLUMNS").click
          first("div#columns-dropdown div.menu div.menu_item", text: "Inheritance").click
          first("div#columns-dropdown", :text => "COLUMNS").click
          page.check "variant-overrides-#{variant3.id}-inherit"

          expect do
            click_button 'Save Changes'
            page.should have_content "Changes saved."
          end.to change(VariantOverride, :count).by(-2)

          VariantOverride.where(id: vo.id).should be_empty
          VariantOverride.where(id: vo3.id).should be_empty
        end

        it "resets stock to defaults" do
          click_button 'Reset Stock to Defaults'
          page.should have_content 'Stocks reset to defaults.'
          vo.reload
          page.should have_input "variant-overrides-#{variant.id}-count_on_hand", with: '1000', placeholder: '12'
          vo.count_on_hand.should == 1000
        end

        it "doesn't reset stock levels if the behaviour is disabled" do
          click_button 'Reset Stock to Defaults'
          vo_no_reset.reload
          page.should have_input "variant-overrides-#{variant2.id}-count_on_hand", with: '40', placeholder: '12'
          vo_no_reset.count_on_hand.should == 40
        end

        it "prompts to save changes before reset if any are pending" do
          fill_in "variant-overrides-#{variant.id}-price", with: '200'
          click_button 'Reset Stock to Defaults'
          page.should have_content "Save changes first"
        end
      end
    end
  end
end
