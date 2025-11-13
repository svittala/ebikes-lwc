Salesforce Org Data Model - Generated from trailheadorg
Objects and Relationships:

## Custom Objects

-   **Order\_\_c** (Reseller Order)
-   **Product\_\_c** (Product)
-   **Product_Family\_\_c** (Product Family)
-   **Order_Item\_\_c** (Order Item)

## Key Relationships

Based on available metadata, the main relationships are:

1. Order**c → Order_Item**c (Master-Detail or Lookup)
2. Product_Family**c → Product**c (Master-Detail or Lookup)
3. Product**c → Order_Item**c (Master-Detail or Lookup)

Note: Detailed relationship information requires advanced SOQL or API access not available in this environment.
