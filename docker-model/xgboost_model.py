# Load training and test datasets
import xgboost as xgb
from sklearn import datasets
from sklearn.model_selection import train_test_split
import os

iris = datasets.load_iris()
x = iris.data[:, 2:]
y = iris.target
x_train, x_test, y_train, _ = train_test_split(x, y, test_size=0.2, random_state=42)
dtrain = xgb.DMatrix(x_train, label=y_train)

# Train and save an XGBoost model
xgb_model = xgb.train(params={'max_depth': 10}, dtrain=dtrain, num_boost_round=10)
xgb_model_path = "/mlflow/tmp/mlruns/{version}/{run_id}/artifacts/xgb_model.pth".format(
    version=os.environ.get("MLFLOW_EXPERIMENT_ID"),
    run_id=os.environ.get("MLFLOW_RUN_ID"))
xgb_model_path_context="xgb_model.pth"
xgb_model.save_model(xgb_model_path)

# Create an `artifacts` dictionary that assigns a unique name to the saved XGBoost model file.
# This dictionary will be passed to `mlflow.pyfunc.save_model`, which will copy the model file
# into the new MLflow Model's directory.
artifacts = {
    "xgb_model": xgb_model_path
}

# Define the model class
import mlflow.pyfunc
class XGBWrapper(mlflow.pyfunc.PythonModel):

    def load_context(self, context):
        import xgboost as xgb
        self.xgb_model = xgb.Booster()
        self.xgb_model.load_model(context.artifacts["xgb_model"])

    def predict(self, context, model_input):
        input_matrix = xgb.DMatrix(model_input.values)
        return self.xgb_model.predict(input_matrix)

# Create a Conda environment for the new MLflow Model that contains the XGBoost library
# as a dependency, as well as the required CloudPickle library
import cloudpickle
conda_env = {
    'channels': ['defaults'],
    'dependencies': [
      'py-xgboost={}'.format(xgb.__version__),
      'cloudpickle={}'.format(cloudpickle.__version__),
    ],
    'name': 'xgb_env'
}

# Save the MLflow Model
# mlflow_pyfunc_model_path = "xgb_mlflow_pyfunc"

mlflow_pyfunc_model_path = "/mlflow/tmp/mlruns/{version}/{run_id}/artifacts/xgb_mlflow_pyfunc".format(version=os.environ.get("MLFLOW_EXPERIMENT_ID"), run_id=os.environ.get("MLFLOW_RUN_ID"))

mlflow.pyfunc.save_model(
        path=mlflow_pyfunc_model_path, python_model=XGBWrapper(), artifacts=artifacts,
        conda_env=conda_env)

# # Load the model in `python_function` format
# loaded_model = mlflow.pyfunc.load_model(mlflow_pyfunc_model_path)
#
# # Evaluate the model
# import pandas as pd
# test_predictions = loaded_model.predict(pd.DataFrame(x_test))
# print(test_predictions)
