# InfrastructureSystems

## 0.5.2

- Improvements in logging

## 0.5.1

- Add time periods operations and print methods. 
- Add redirection of stdout to log events during external function execution 
- Add new exceptios for PowerSimulations

## 0.5.0

- Update template for autogeneration of structs to consider internal_default values
- Add Code to support parametrized structs in seralization and de-serialization
- Add the ext field in internal for extensions of structs.

## 0.4.4

- Fix printing of < in generated structs

## 0.4.3

- Fix inital time generation from contiguous forecasts

## 0.4.2

- Fix docstring creation in struct generation code

## 0.4.1

- Update docstring printing in auto generation code

## 0.4.0

- Add validation for contigous forecasts
- Bug fix in table data parsing

## 0.3.0

- Use accessor functions to retrieve forecasts instead of labels

## 0.2.4

- Return components from remove_component functions
- Fix incorrect docstrings

## 0.2.3

- Subsetting of HDF5 file when reading forecast data

## 0.2.2

- Automatic deletition of the temporary files

## 0.2.1

- Remove assertion when component label is not present

## 0.2.0

- Update use of forecasts to store them in disk

## 0.1.4

- Bugfix: Changed the use of get_data to get_time series in get_forecast_value 577f5e2

## 0.1.3

- Fix strip_module_names #16
