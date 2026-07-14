# Data

This project uses the **Olist Brazilian E-Commerce Public Dataset**.

**Source:** https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce

The raw data is not included in this repository.
Download it from the original Kaggle source.

## CSV files used

Place the following files in this `data/` folder:

- `olist_orders_dataset.csv`
- `olist_order_items_dataset.csv`
- `olist_order_payments_dataset.csv`
- `olist_customers_dataset.csv`
- `olist_products_dataset.csv`
- `olist_order_reviews_dataset.csv`
- `product_category_name_translation.csv`

## How to download

**Option A — Kaggle website**

1. Open the dataset page on Kaggle and click **Download**.
2. Unzip the archive.
3. Copy the CSV files listed above into this `data/` folder.

**Option B — Kaggle CLI**

```bash
pip install kaggle
# create an API token at kaggle.com -> Settings -> Create New Token
mkdir -p ~/.kaggle && mv ~/Downloads/kaggle.json ~/.kaggle/ && chmod 600 ~/.kaggle/kaggle.json
kaggle datasets download -d olistbr/brazilian-ecommerce -p data/ --unzip
```

## Notes

- All CSVs are UTF-8 encoded.
- The `.csv` files are excluded from version control via `.gitignore`.
- Not all bundled files are required; `sellers` and `geolocation` are optional and
  listed under *Future Improvements* in the main README.
