require "rails_helper"

RSpec.describe Employees::List do
  describe ".filter" do
    let(:as_of) { Date.new(2024, 6, 1) }

    def filtered(**filters) = described_class.filter(filters, as_of: as_of)

    it "returns everyone when nothing is filtered" do
      employees = create_list(:employee, 2)

      expect(filtered).to match_array(employees)
    end

    describe "q" do
      let!(:ada) { create(:employee, name: "Ada Lovelace", email: "countess@example.com", title: "Analyst") }
      let!(:grace) { create(:employee, name: "Grace Hopper", email: "grace@navy.example.com", title: "Rear Admiral") }

      it "matches part of the name, the email or the title, ignoring case" do
        expect(filtered(q: "LOVE")).to contain_exactly(ada)
        expect(filtered(q: "navy")).to contain_exactly(grace)
        expect(filtered(q: "admiral")).to contain_exactly(grace)
      end

      it "squishes the term the way the name column is" do
        expect(filtered(q: "  ada   lovelace ")).to contain_exactly(ada)
      end

      it "treats % and _ as literal characters, not wildcards" do
        underscored = create(:employee, email: "ada_l@example.com")

        expect(filtered(q: "_")).to contain_exactly(underscored)
        expect(filtered(q: "%")).to be_empty
      end

      it "looks up the id when the term parses as a UUID, in either case" do
        expect(filtered(q: ada.id)).to contain_exactly(ada)
        expect(filtered(q: ada.id.upcase)).to contain_exactly(ada)
      end

      it "does not match part of an id" do
        expect(filtered(q: ada.id.first(8))).to be_empty
      end
    end

    { department_id: :department, country_id: :country, level_id: :level }.each do |key, reference|
      it "keeps employees in any of the given #{reference.to_s.pluralize}" do
        first, second, third = create_list(reference, 3)
        in_first = create(:employee, reference => first)
        in_second = create(:employee, reference => second)
        create(:employee, reference => third)

        expect(filtered(key => [ first.id, second.id ])).to contain_exactly(in_first, in_second)
      end
    end

    it "is empty rather than an error for an id that does not parse" do
      create(:employee)

      expect(filtered(department_id: [ "nonsense" ])).to be_empty
    end

    it "ignores blank ids, which is what an empty multi-select sends" do
      employee = create(:employee)

      expect(filtered(department_id: [ "" ])).to contain_exactly(employee)
    end

    it "matches the whole title, after the same squish the column gets" do
      senior = create(:employee, title: "Senior Engineer")
      create(:employee, title: "Senior Engineer II")

      expect(filtered(title: " Senior   Engineer ")).to contain_exactly(senior)
    end

    describe "status" do
      let!(:active) { create(:employee, hire_date: Date.new(2024, 1, 1)) }
      let!(:leaving) { create(:employee, hire_date: Date.new(2024, 1, 1), exit_date: as_of) }
      let!(:pending) { create(:employee, hire_date: as_of + 1) }
      let!(:exited) { create(:employee, hire_date: Date.new(2024, 1, 1), exit_date: as_of - 1) }

      it "counts an employee whose exit date is as_of as active" do
        expect(filtered(status: "active")).to contain_exactly(active, leaving)
      end

      it "reads pending and exited as of the same date" do
        expect(filtered(status: "pending")).to contain_exactly(pending)
        expect(filtered(status: "exited")).to contain_exactly(exited)
      end

      it "raises on a status the constant does not name, rather than returning an empty page" do
        expect { filtered(status: "retired") }
          .to raise_error(InvalidParameter, "status must be one of pending, active, exited")
      end
    end

    it "requires every filter to match" do
      engineering = create(:department)
      match = create(:employee, name: "Ada Lovelace", department: engineering, hire_date: Date.new(2024, 1, 1))
      create(:employee, name: "Ada Byron", hire_date: Date.new(2024, 1, 1))
      create(:employee, name: "Grace Hopper", department: engineering, hire_date: Date.new(2024, 1, 1))
      create(:employee, name: "Ada King", department: engineering, hire_date: as_of + 1)

      expect(filtered(q: "ada", department_id: [ engineering.id ], status: "active")).to contain_exactly(match)
    end

    it "adds no join and no order, so counting it never pays for the salary lookup" do
      sql = filtered(q: "ada", title: "Engineer", status: "active", department_id: [ SecureRandom.uuid ]).to_sql

      expect(sql).not_to include("JOIN", "ORDER BY")
    end
  end

  describe ".sort" do
    let(:as_of) { Date.new(2024, 6, 1) }

    def sorted(sort) = described_class.sort(Employee.with_salary_as_of(as_of), sort).to_a

    it "defaults to name, ignoring case, so adam comes before Bob" do
      %w[Bob Zoe adam alice].each { |name| create(:employee, name: name) }

      expect(sorted(nil).map(&:name)).to eq(%w[adam alice Bob Zoe])
      expect(sorted("-name").map(&:name)).to eq(%w[Zoe Bob alice adam])
    end

    # Written in descending id order. Tied rows otherwise come back in insertion order, which would
    # pass without the tiebreak.
    it "breaks a tie on id, ascending either way, so offset pages never overlap" do
      ids = Array.new(3) { SecureRandom.uuid_v7 }.sort
      ids.reverse_each { |id| create(:employee, id: id, name: "Sam Smith") }

      expect(sorted("name").map(&:id)).to eq(ids)
      expect(sorted("-name").map(&:id)).to eq(ids)
    end

    it "sorts by hire date" do
      later = create(:employee, hire_date: Date.new(2024, 3, 1))
      earlier = create(:employee, hire_date: Date.new(2024, 1, 1))

      expect(sorted("hire_date")).to eq([ earlier, later ])
      expect(sorted("-hire_date")).to eq([ later, earlier ])
    end

    it "puts employees with no exit date last either way" do
      staying = create(:employee, hire_date: Date.new(2020, 1, 1))
      early = create(:employee, hire_date: Date.new(2020, 1, 1), exit_date: Date.new(2023, 1, 1))
      late = create(:employee, hire_date: Date.new(2020, 1, 1), exit_date: Date.new(2024, 1, 1))

      expect(sorted("exit_date")).to eq([ early, late, staying ])
      expect(sorted("-exit_date")).to eq([ late, early, staying ])
    end

    describe "by salary" do
      def paid(amount_cents, exit_date: nil)
        create(:employee, hire_date: Date.new(2024, 1, 1), exit_date: exit_date).tap do |employee|
          create(:salary_revision, employee: employee, effective_date: employee.hire_date, amount_cents: amount_cents)
        end
      end

      it "opens -salary on the highest paid and puts anyone unpaid last either way" do
        low = paid(10_000_000)
        high = paid(20_000_000)
        unpaid = create(:employee, hire_date: Date.new(2024, 1, 1))

        expect(sorted("-salary")).to eq([ high, low, unpaid ])
        expect(sorted("salary")).to eq([ low, high, unpaid ])
      end

      it "does not rank someone who has left among the paid" do
        low = paid(10_000_000)
        gone = paid(90_000_000, exit_date: as_of - 1)

        expect(sorted("-salary")).to eq([ low, gone ])
      end
    end

    it "sorts by department name, ignoring case" do
      sales = create(:employee, department: create(:department, name: "Sales"))
      engineering = create(:employee, department: create(:department, name: "engineering"))
      finance = create(:employee, department: create(:department, name: "Finance"))

      expect(sorted("department")).to eq([ engineering, finance, sales ])
      expect(sorted("-department")).to eq([ sales, finance, engineering ])
    end

    it "sorts by country name, ignoring case" do
      india = create(:employee, country: create(:country, name: "India"))
      france = create(:employee, country: create(:country, name: "france"))

      expect(sorted("country")).to eq([ france, india ])
      expect(sorted("-country")).to eq([ india, france ])
    end

    it "sorts level by rank, so L2 comes before L10" do
      senior = create(:employee, level: create(:level, code: "L10", rank: 10))
      junior = create(:employee, level: create(:level, code: "L2", rank: 2))

      expect(sorted("level")).to eq([ junior, senior ])
      expect(sorted("-level")).to eq([ senior, junior ])
    end

    it "raises on a key it does not know, rather than falling back to the default" do
      %w[salry id Name --name -].each do |sort|
        expect { described_class.sort(Employee.all, sort) }.to raise_error(UnknownSortKey, "#{sort} is not a sortable key")
      end
    end

    it "chains onto filter, which alone gives the total" do
      sales = create(:department, name: "Sales")
      engineering = create(:department, name: "Engineering")
      ada = create(:employee, name: "Ada Lovelace", department: sales, hire_date: Date.new(2024, 1, 1))
      adam = create(:employee, name: "Adam Smith", department: engineering, hire_date: Date.new(2024, 1, 1))
      create(:salary_revision, employee: ada, amount_cents: 20_000_000)
      create(:salary_revision, employee: adam, amount_cents: 10_000_000)
      create(:employee, name: "Ada King", department: sales, hire_date: as_of + 1)
      create(:employee, name: "Grace Hopper", department: sales, hire_date: Date.new(2024, 1, 1))

      base = described_class.filter({ q: "ada", status: "active" }, as_of: as_of)

      expect(base.count).to eq(2)
      expect(described_class.sort(base.with_salary_as_of(as_of), "department")).to eq([ adam, ada ])
      expect(described_class.sort(base.with_salary_as_of(as_of), "-salary")).to eq([ ada, adam ])
    end
  end
end
