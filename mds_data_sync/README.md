
- src/HEAL_Companion_Tool.ipynb - original notebook from Platform to calculate CEDAR completion from MDS endpoint
- ./lambda_function.py - pulls from MDS endpoint and calculates CEDAR completion; data sink directly supports HEAL data progress tracker (e.g. `heal_mds_data_sync` on Lambda)



- For tests

Add `lambda_handler(None, None)` to `lambda_function.py`