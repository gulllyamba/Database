-- сделать подписи к колонкам, где какие единицы

BEGIN;

CREATE TABLE region (
    id_region uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name varchar(100) NOT NULL UNIQUE,
    description varchar(200),
    sale_bonus_percent numeric(5, 2) NOT NULL DEFAULT 0 CHECK (sale_bonus_percent >= 0 AND sale_bonus_percent <= 100),
    rent_bonus_percent numeric(5, 2) NOT NULL DEFAULT 0 CHECK (rent_bonus_percent >= 0 AND rent_bonus_percent <= 100),

    id_parent uuid,

    CONSTRAINT fk_region_parent
        FOREIGN KEY (id_parent)
        REFERENCES region(id_region)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

COMMENT ON TABLE region IS 'Географические регионы';

CREATE TABLE bank (
    bic char(9) PRIMARY KEY CHECK (bic ~ '^[0-9]{9}$'),
    name varchar(100) NOT NULL UNIQUE,
    license_number varchar(4) NOT NULL UNIQUE CHECK (license_number ~ '^[0-9]{1,4}$'),
    settlement_account char(20) NOT NULL UNIQUE CHECK (settlement_account ~ '^40(7|8)[0-9]{17}$'),
    correspondent_account char(20) NOT NULL UNIQUE CHECK (correspondent_account ~ '^301[0-9]{17}$')
);

COMMENT ON TABLE bank IS 'Банки, через которые оформляется ипотека и проводятся платежи';

CREATE TYPE employee_role_code AS ENUM (
    'REALTOR',
    'MANAGER',
    'ACCOUNTANT',
    'DIRECTOR'
);

CREATE TABLE employee_role (
    code employee_role_code PRIMARY KEY,
    name varchar(11) NOT NULL UNIQUE
);

COMMENT ON TABLE employee_role IS 'Справочник должностей сотрудников агентства';

CREATE TABLE employee (
    id_employee uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    passport_series char(4) NOT NULL CHECK (passport_series ~ '^[0-9]{4}$'),
    passport_number char(6) NOT NULL CHECK (passport_number ~ '^[0-9]{6}$'),
    inn char(12) NOT NULL UNIQUE CHECK (inn ~ '^[0-9]{12}$'),
    full_name varchar(100) NOT NULL,
    phone varchar(12) NOT NULL UNIQUE CHECK (phone ~ '^((\+?7)|8)[0-9]{10}$'),
    birth_date date NOT NULL,
    hire_date date NOT NULL CHECK (hire_date >= birth_date + INTERVAL '18 years'),
    dismissal_date date CHECK (dismissal_date IS NULL OR dismissal_date >= hire_date),

    role_code employee_role_code NOT NULL,
    id_region uuid NOT NULL,
    id_manager uuid CHECK (id_manager <> id_employee),

    CONSTRAINT fk_employee_role
        FOREIGN KEY (role_code)
        REFERENCES employee_role(code)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT fk_employee_region
        FOREIGN KEY (id_region)
        REFERENCES region(id_region)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT fk_employee_manager
        FOREIGN KEY (id_manager)
        REFERENCES employee(id_employee)
        ON DELETE SET NULL
        ON UPDATE CASCADE,

    CONSTRAINT uq_employee_passport
        UNIQUE (passport_series, passport_number)
);

COMMENT ON TABLE employee IS 'Сотрудники агенства: риелторы, менеджеры, бухгалтер, управляющий';

CREATE TABLE seller (
    id_seller uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    passport_series char(4) NOT NULL CHECK (passport_series ~ '^[0-9]{4}$'),
    passport_number char(6) NOT NULL CHECK (passport_number ~ '^[0-9]{6}$'),
    full_name varchar(100) NOT NULL,
    address varchar(200) NOT NULL,

    CONSTRAINT uq_seller_passport
        UNIQUE (passport_series, passport_number)
);

COMMENT ON TABLE seller IS 'Продавцы и арендодатели недвижимости';

CREATE TABLE buyer (
    id_buyer uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    passport_series char(4) NOT NULL CHECK (passport_series ~ '^[0-9]{4}$'),
    passport_number char(6) NOT NULL CHECK (passport_number ~ '^[0-9]{6}$'),
    full_name varchar(100) NOT NULL,
    address varchar(200) NOT NULL,

    CONSTRAINT uq_buyer_passport
        UNIQUE (passport_series, passport_number)
);

COMMENT ON TABLE buyer IS 'Покупатели и арендаторы недвижимости';

CREATE TYPE housing_type AS ENUM (
    'APARTMENT',
    'HOUSE',
    'COTTAGE',
    'PENTHOUSE'
);

CREATE TABLE housing (
    id_housing uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    type housing_type NOT NULL,
    square numeric(10, 2) NOT NULL CHECK (square > 0),
    address varchar(200) NOT NULL,
    floor smallint NOT NULL CHECK (floor > 0),
    house_number smallint NOT NULL CHECK (house_number > 0),
    ceiling_height numeric(4, 2) NOT NULL CHECK (ceiling_height > 0),

    id_region uuid NOT NULL,
    id_manager uuid NOT NULL,
    id_seller uuid NOT NULL,

    CONSTRAINT fk_housing_region
        FOREIGN KEY (id_region)
        REFERENCES region(id_region)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT fk_housing_manager
        FOREIGN KEY (id_manager)
        REFERENCES employee(id_employee)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT fk_housing_seller
        FOREIGN KEY (id_seller)
        REFERENCES seller(id_seller)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT uq_housing_address
        UNIQUE (id_region, address, house_number)
);

COMMENT ON TABLE housing IS 'Недвижимость';

CREATE TYPE contract_type AS ENUM (
    'RENT',
    'SALE'
);

CREATE TABLE cooperation_contract (
    id_contract uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    conclusion_date date NOT NULL,
    agency_reward smallint NOT NULL CHECK (agency_reward > 0), -- награда агенству(десятки тысяч)
    contract_type contract_type NOT NULL,
    property_price smallint NOT NULL CHECK (property_price > 0), -- стоимость жилья/аренды (десятки тысяч)

    id_seller uuid NOT NULL,
    id_housing uuid NOT NULL,
    id_manager uuid NOT NULL,
    id_previous_contract uuid,

    CONSTRAINT fk_cooperation_contract_seller
        FOREIGN KEY (id_seller)
        REFERENCES seller(id_seller)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT fk_cooperation_contract_housing
        FOREIGN KEY (id_housing)
        REFERENCES housing(id_housing)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT fk_cooperation_contract_manager
        FOREIGN KEY (id_manager)
        REFERENCES employee(id_employee)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT fk_cooperation_contract_previous
        FOREIGN KEY (id_previous_contract)
        REFERENCES cooperation_contract(id_contract)
        ON DELETE SET NULL
        ON UPDATE CASCADE,

    CONSTRAINT chk_contract_not_self_previous
        CHECK (id_previous_contract <> id_contract)
);

COMMENT ON TABLE cooperation_contract IS 'Договоры о сотрудничестве с агентством (продажа/аренда)';

CREATE TYPE payment_type AS ENUM (
    'CASH',
    'MORTGAGE',
    'BANK_TRANSFER',
    'LETTER_OF_CREDIT'
);

CREATE TABLE purchase_contract (
    id_contract uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    subject text NOT NULL,
    conclusion_date date NOT NULL,
    sale_amount smallint NOT NULL CHECK (sale_amount >= 1), -- сумма продажи (миллионы)
    reward_amount smallint NOT NULL CHECK (reward_amount >= 1), -- сумма вознаграждения агенству (десятки тысяч)
    payment_type payment_type NOT NULL,

    mortgage_percent numeric(5, 2),
    mortgage_duration_month smallint,

    id_housing uuid NOT NULL,
    id_buyer uuid NOT NULL,
    id_realtor uuid NOT NULL,
    bic char(9),

    CONSTRAINT fk_purchase_contract_housing
        FOREIGN KEY (id_housing)
        REFERENCES housing(id_housing)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT fk_purchase_contract_buyer
        FOREIGN KEY (id_buyer)
        REFERENCES buyer(id_buyer)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT fk_purchase_contract_realtor
        FOREIGN KEY (id_realtor)
        REFERENCES employee(id_employee)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT fk_purchase_contract_bank
        FOREIGN KEY (bic)
        REFERENCES bank(bic)
        ON DELETE SET NULL
        ON UPDATE CASCADE,

    CONSTRAINT chk_mortgage_values
        CHECK ((mortgage_percent IS NULL or (mortgage_percent >= 0 and mortgage_percent <= 100))
            and (mortgage_duration_month IS NULL or mortgage_duration_month > 0)),
    CONSTRAINT chk_mortgage_required
        CHECK (payment_type <> 'MORTGAGE' or (mortgage_percent IS NOT NULL AND mortgage_duration_month IS NOT NULL))
);

COMMENT ON TABLE purchase_contract IS 'Договоры о покупке недвижимости';

CREATE TABLE rent_contract (
    id_contract uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    subject text NOT NULL,
    conclusion_date date NOT NULL,
    monthly_price smallint NOT NULL CHECK (monthly_price > 0), -- стоимость в месяц(десятки тысяч)
    duration_months smallint NOT NULL CHECK (duration_months > 0),
--  payment_type payment_type NOT NULL,

    id_housing uuid NOT NULL,
    id_tenant uuid NOT NULL,
    id_realtor uuid NOT NULL,
    bic char(9) NOT NULL,
    id_previous_contract uuid,

    CONSTRAINT fk_rent_contract_housing
        FOREIGN KEY (id_housing)
        REFERENCES housing(id_housing)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT fk_rent_contract_buyer
        FOREIGN KEY (id_tenant)
        REFERENCES buyer(id_buyer)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT fk_rent_contract_realtor
        FOREIGN KEY (id_realtor)
        REFERENCES employee(id_employee)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT fk_rent_contract_bank
        FOREIGN KEY (bic)
        REFERENCES bank(bic)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT fk_rent_contract_previous
        FOREIGN KEY (id_previous_contract)
        REFERENCES rent_contract(id_contract)
        ON DELETE SET NULL
        ON UPDATE CASCADE,

    CONSTRAINT chk_rent_not_self_previous
        CHECK (id_previous_contract <> id_contract)
);

COMMENT ON TABLE rent_contract IS 'Договоры об аренде недвижимости';

CREATE TYPE payment_document_type AS ENUM (
    'INCOMING',
    'OUTGOING'
);

CREATE TABLE payment_document (
    id_document uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    document_type payment_document_type NOT NULL,
    amount smallint NOT NULL CHECK (amount > 0), -- сумма платежа (десятки тысяч)
    document_date date NOT NULL,

    id_purchase_contract uuid,
    id_rent_contract uuid,
    id_recipient_employee uuid,
    id_accountant uuid NOT NULL,

    CONSTRAINT fk_payment_purchase
        FOREIGN KEY (id_purchase_contract)
        REFERENCES purchase_contract(id_contract)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT fk_payment_rent
        FOREIGN KEY (id_rent_contract)
        REFERENCES rent_contract(id_contract)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT fk_payment_recipient
        FOREIGN KEY (id_recipient_employee)
        REFERENCES employee(id_employee)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT fk_payment_accountant
        FOREIGN KEY (id_accountant)
        REFERENCES employee(id_employee)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT chk_accountant_not_recipient
        CHECK (id_accountant <> id_recipient_employee),

    CONSTRAINT chk_payment_contract_exclusive
        CHECK ((id_purchase_contract IS NOT NULL and id_rent_contract IS NULL)
            or (id_purchase_contract IS NULL and id_rent_contract IS NOT NULL))
);

COMMENT ON TABLE payment_document IS 'Платежные документы (входящие/исходящие)';

COMMIT;