import psycopg2
import random
from faker import Faker
from datetime import datetime

conn = psycopg2.connect(
    dbname="find_your_place",
    user="postgres",
    password="0U3Sre!!",
    host="localhost",
    port="5432"
)
cursor = conn.cursor()
fake = Faker('ru_RU')

fake.seed_instance(42)
random.seed(42)

region_uuids = [
    '22222222-2222-2222-2222-222222222222',
    '33333333-3333-3333-3333-333333333333',
    '44444444-4444-4444-4444-444444444444',
    '55555555-5555-5555-5555-555555555555',
]

employees = []
for i in range(50):
    p_series = f"{random.randint(1000, 9999)}"
    p_number = f"{random.randint(100000, 999999)}"
    inn = str(random.randint(100000000000, 999999999999))
    phone = f"+79{random.randint(100000000, 999999999)}"
    full_name = fake.name()
    birth_date = fake.date_of_birth(minimum_age=20, maximum_age=60).strftime('%Y-%m-%d')

    hire_date = fake.date_between(start_date='-2y', end_date='today').strftime('%Y-%m-%d')

    if i < 24: role = 'REALTOR'
    elif i < 44: role = 'MANAGER'
    elif i < 49: role = 'ACCOUNTANT'
    else: role = 'DIRECTOR'

    region = random.choice(region_uuids)

    cursor.execute("""
        INSERT INTO employee (passport_series, passport_number, inn, full_name, phone, birth_date, hire_date, role_code, id_region)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        RETURNING id_employee
    """, (p_series, p_number, inn, full_name, phone, birth_date, hire_date, role, region))

    emp_id = cursor.fetchone()[0]
    employees.append(emp_id)

print(f"Сгенерировано {len(employees)} сотрудников.")

sellers = []
for _ in range(100):
    p_series = f"{random.randint(1000, 9999)}"
    p_number = f"{random.randint(100000, 999999)}"
    cursor.execute("""
        INSERT INTO seller (passport_series, passport_number, full_name, address)
        VALUES (%s, %s, %s, %s)
        RETURNING id_seller
    """, (p_series, p_number, fake.name(), fake.address()))
    sellers.append(cursor.fetchone()[0])

print(f"Сгенерировано {len(sellers)} продавцов.")

buyers = []
for _ in range(100):
    p_series = f"{random.randint(1000, 9999)}"
    p_number = f"{random.randint(100000, 999999)}"
    cursor.execute("""
        INSERT INTO buyer (passport_series, passport_number, full_name, address)
        VALUES (%s, %s, %s, %s)
        RETURNING id_buyer
    """, (p_series, p_number, fake.name(), fake.address()))
    buyers.append(cursor.fetchone()[0])

print(f"Сгенерировано {len(buyers)} покупателей.")

houses = []
for _ in range(200):
    h_type = random.choice(['APARTMENT', 'HOUSE', 'COTTAGE', 'PENTHOUSE'])
    square = round(random.uniform(30.0, 200.0), 2)
    address = fake.street_address()
    floor = random.randint(1, 25)
    house_number = random.randint(1, 500)
    ceiling = round(random.uniform(2.5, 4.5), 2)
    region = random.choice(region_uuids)
    manager = random.choice(employees[24:43])
    seller = random.choice(sellers)

    cursor.execute("""
        INSERT INTO housing (type, square, address, floor, house_number, ceiling_height, id_region, id_manager, id_seller)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
        RETURNING id_housing
    """, (h_type, square, address, floor, house_number, ceiling, region, manager, seller))
    houses.append(cursor.fetchone()[0])

print(f"Сгенерировано {len(houses)} объектов недвижимости.")

# ==========================================

bank_bics = ['044525225', '044525187', '044030790']

cursor.execute("SELECT id_employee FROM employee WHERE role_code = 'ACCOUNTANT'")
accountant_ids = [row[0] for row in cursor.fetchall()]

cursor.execute("SELECT e.id_employee, r.sale_bonus_percent, r.rent_bonus_percent FROM employee e JOIN region r ON e.id_region = r.id_region WHERE role_code = 'REALTOR'")
rows = cursor.fetchall()
realtor_ids = [row[0] for row in rows]
realtor_sale_bonus = [row[1] for row in rows]
realtor_rent_bonus = [row[2] for row in rows]

random.shuffle(houses)
coop_contracts = []
coop_contracts_info = []
for i in range(200):
    house_id = houses[i]
    c_type = random.choice(['RENT', 'SALE'])
    if c_type == 'RENT':
        price = random.randint(3, 50) # от 30000 до 500000
        reward = random.randint(100, 500) # от 10000 до 50000
    else:
        price = random.randint(3, 50) * 100 # от 3000000 до 50000000
        reward = random.randint(10, 50) # от 100000 до 500000

    date = fake.date_between(start_date='-2y', end_date='today').strftime('%Y-%m-%d')
    seller = random.choice(sellers)
    manager = random.choice(employees[24:44])

    cursor.execute("""
        INSERT INTO cooperation_contract (conclusion_date, agency_reward, contract_type, property_price, id_seller, id_housing, id_manager)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        RETURNING id_contract
    """, (date, reward, c_type, price, seller, house_id, manager))
    coop_id = cursor.fetchone()[0]

    coop_contracts_info.append({
        'id': coop_id,
        'house': house_id,
        'price': price,
        'reward': reward,
        'date': date,
        'type': c_type,
        'manager_id' : manager
    })

print(f"Сгенерировано {len(coop_contracts_info)} договоров о сотрудничестве.")

purchase_contracts = []
sale_contracts = [c for c in coop_contracts_info if c['type'] == 'SALE']
sale_contracts = sale_contracts[:(len(sale_contracts) // 2)]
for coop in sale_contracts:
    house = coop['house']
    amount = coop['price'] / 100

    coop_date = datetime.strptime(coop['date'], '%Y-%m-%d')
    date = fake.date_between(start_date=coop_date, end_date='today').strftime('%Y-%m-%d')

    reward = coop['reward']
    p_type = random.choice(['CASH', 'MORTGAGE', 'BANK_TRANSFER', 'LETTER_OF_CREDIT'])
    bic = random.choice(bank_bics) if p_type != 'CASH' else None

    mortgage_percent = None
    mortgage_duration = None
    if p_type == 'MORTGAGE':
        mortgage_percent = round(random.uniform(5.0, 25.0), 2)
        mortgage_duration = random.randint(12, 360)

    buyer = random.choice(buyers)

    realtor_idx = random.randint(0, len(realtor_ids)-1)
    realtor = realtor_ids[realtor_idx]

    subject = f"Купля-продажа объекта {house}"

    cursor.execute("""
        INSERT INTO purchase_contract (subject, conclusion_date, sale_amount, reward_amount, payment_type, mortgage_percent, mortgage_duration_month, id_housing, id_buyer, id_realtor, bic)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
        RETURNING id_contract
    """, (subject, date, amount, reward, p_type, mortgage_percent, mortgage_duration, house, buyer, realtor, bic))
    purchase_contracts.append(cursor.fetchone()[0])

    reward_to_manager = int(0.1 * reward)
    reward_to_realtor = int((0.05 + float(realtor_sale_bonus[realtor_idx]) / 100) * reward)
    accountant = random.choice([a for a in accountant_ids])
    cursor.execute("""
        INSERT INTO payment_document (document_type, amount, document_date, id_purchase_contract, id_rent_contract, id_recipient_employee, id_accountant)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
    """, ('OUTGOING', reward_to_realtor, date, purchase_contracts[-1], None, realtor, accountant))

    cursor.execute("""
        INSERT INTO payment_document (document_type, amount, document_date, id_purchase_contract, id_rent_contract, id_recipient_employee, id_accountant)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
    """, ('OUTGOING', reward_to_manager, date, purchase_contracts[-1], None, coop['manager_id'], accountant))

    cursor.execute("""
        INSERT INTO payment_document (document_type, amount, document_date, id_purchase_contract, id_rent_contract, id_recipient_employee, id_accountant)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
    """, ('INCOMING', reward, date, purchase_contracts[-1], None, None, accountant))

print(f"Сгенерировано {len(purchase_contracts)} договоров покупки.")

rent_contracts = []
rent_coop_contracts = [c for c in coop_contracts_info if c['type'] == 'RENT']
rent_coop_contracts = rent_coop_contracts[:(len(rent_coop_contracts) // 2)]
for coop in rent_coop_contracts:
    house = coop['house']
    price = coop['price']
    reward = coop['reward']

    coop_date = datetime.strptime(coop['date'], '%Y-%m-%d')
    date = fake.date_between(start_date=coop_date, end_date='today').strftime('%Y-%m-%d')

    duration = random.randint(3, 24)
    tenant = random.choice(buyers)

    # realtor = random.choice(realtor_ids)
    realtor_idx = random.randint(0, len(realtor_ids) - 1)
    realtor = realtor_ids[realtor_idx]

    bic = random.choice(bank_bics)
    subject = f"Аренда объекта {house}"

    cursor.execute("""
        INSERT INTO rent_contract (subject, conclusion_date, monthly_price, duration_months, id_housing, id_tenant, id_realtor, bic)
        VALUES (%s, %s, %s, %s, %s, %s, %s, %s)
        RETURNING id_contract
    """, (subject, date, price, duration, house, tenant, realtor, bic))
    rent_contracts.append(cursor.fetchone()[0])

    reward_to_manager = int(0.15 * reward)
    reward_to_realtor = int((0.05 + float(realtor_rent_bonus[realtor_idx] / 100)) * reward)
    accountant = random.choice([a for a in accountant_ids])
    cursor.execute("""
        INSERT INTO payment_document (document_type, amount, document_date, id_purchase_contract, id_rent_contract, id_recipient_employee, id_accountant)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
    """, ('OUTGOING', reward_to_realtor, date, None, rent_contracts[-1], realtor, accountant))

    cursor.execute("""
        INSERT INTO payment_document (document_type, amount, document_date, id_purchase_contract, id_rent_contract, id_recipient_employee, id_accountant)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
    """, ('OUTGOING', reward_to_manager, date, None, rent_contracts[-1], coop['manager_id'], accountant))

    cursor.execute("""
        INSERT INTO payment_document (document_type, amount, document_date, id_purchase_contract, id_rent_contract, id_recipient_employee, id_accountant)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
    """, ('INCOMING', reward, date, None, rent_contracts[-1], None, accountant))

print(f"Сгенерировано {len(rent_contracts)} договоров аренды.")

# for _ in range(200):
#     doc_type = random.choice(['INCOMING', 'OUTGOING'])
#
#     if random.choice([True, False]):
#         contract_id = random.choice(purchase_contracts)
#         contract_type_str = 'purchase'
#         cursor.execute("SELECT conclusion_date FROM purchase_contract WHERE id_contract = %s", (contract_id,))
#         contract_date = cursor.fetchone()[0]
#     else:
#         contract_id = random.choice(rent_contracts)
#         contract_type_str = 'rent'
#         cursor.execute("SELECT conclusion_date FROM rent_contract WHERE id_contract = %s", (contract_id,))
#         contract_date = cursor.fetchone()[0]
#
#     date = fake.date_between(start_date=contract_date, end_date='today').strftime('%Y-%m-%d')
#
#     if doc_type == 'INCOMING':
#         amount = random.randint(5, 50)
#     else:
#         amount = random.randint(1, 15)
#
#     recipient = random.choice(employees[:44])
#     accountant = random.choice([a for a in accountant_ids])
#
#     if contract_type_str == 'purchase':
#         p_contract = contract_id
#         r_contract = None
#     else:
#         p_contract = None
#         r_contract = contract_id
#
#     cursor.execute("""
#         INSERT INTO payment_document (document_type, amount, document_date, id_purchase_contract, id_rent_contract, id_recipient_employee, id_accountant)
#         VALUES (%s, %s, %s, %s, %s, %s, %s)
#     """, (doc_type, amount, date, p_contract, r_contract, recipient, accountant))
# print(f"Сгенерировано 200 платежных документов.")

conn.commit()
cursor.close()
conn.close()
print("Все данные успешно сохранены в БД!")