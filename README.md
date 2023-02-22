# ssbf-lib: A Fortran library, for importing, reading and writing "Simple ultraSonic anemometer Binary Format"

## Main purpose and usefulness

Three-dimensional anemometers can easily provide fast-sampling (10Hz+), accurate and high-resolution (1cm/s, 0.01°C) wind and temperature data whose processing (for example using _eddy covariance_ and Monin-Obukhov similarity theory) can provide both high-resolution mean wind and mean temperature information, and turbulence indicators like friction velocity, turbulent sensible heat flux or Obukhov length. These data may in turn be used as a basis for quantifying or predicting the "dispersivity" of lower atmosphere (the "Planetary Boundary Layer"), that is, the tendency of air in contact or close to the Earth surface to dilute and transport trace gases (e.g. human-generated pollutants) and particulates (PM-x, pollens, spores, tiny animals).

Data from three-dimensional ultrasonic anemometers are most often collected in proprietary format files, with typically a hourly organization.

Adoption of a hourly organization, i.e. files containing data collected during a specific hour, is quite a historical heritage: at 10 Hz, 36000 sonic quadruples (u,v,w,t) can be expected in a file: a number manageable enough, and likely to be stored in RAM on most computers from ate Nineties onwards.

The lack of standardization, however, made difficult to share data among users. The textual nature of some of these formats added to this issue, inducing inefficiency in data retrieval and storage.

The SSB format was developed to address these problems: it is a binary format, efficiently accessible in stream mode.

Its _daily_ organization also encourages to deal with phenomena occurring on a time scale longer than one hour, as for example the tendency of airflow to recirculate in breeze regimens.

## File naming convention
