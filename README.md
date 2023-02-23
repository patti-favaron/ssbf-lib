# ssbf-lib: A Fortran library for importing, reading and writing "Simple ultraSonic anemometer Binary Format" data files

by Patrizia Favaron (also mentioned as "the author" in following lines).

## Motivation

Three-dimensional anemometers can easily provide fast-sampling (10Hz+), accurate and high-resolution (1cm/s, 0.01°C) wind and temperature data whose processing (for example using _eddy covariance_ and Monin-Obukhov similarity theory) can provide both high-resolution mean wind and mean temperature information, and turbulence indicators like friction velocity, turbulent sensible heat flux or Obukhov length. These data may in turn be used as a basis for quantifying or predicting the "dispersivity" of lower atmosphere (the "Planetary Boundary Layer"), that is, the tendency of air in contact or close to the Earth surface to dilute and transport trace gases (e.g. human-generated pollutants) and particulates (PM-x, pollens, spores, tiny animals).

Data from three-dimensional ultrasonic anemometers are most often collected in proprietary format files, with typically a hourly organization.

Adoption of a hourly organization, i.e. files containing data collected during a specific hour, is quite a historical heritage: at 10 Hz, 36000 sonic quadruples (u,v,w,t) can be expected in a file: a number manageable enough, and likely to be stored in RAM on most computers from ate Nineties onwards.

The lack of standardization, however, made difficult to share data among users. The textual nature of some of these formats added to this issue, inducing inefficiency in data retrieval and storage.

The SSB format was developed to address these problems: it is a binary format, efficiently accessible in stream mode.

Its _daily_ organization also encourages to deal with phenomena occurring on a time scale longer than one hour, as for example the tendency of airflow to recirculate in breeze regimens, which can be fully appreciated on a daily scale; addressing the study of such more-than-hourly phenomena using hourly files could be (by the author's direct experience) quite exposing to a lot of nitty-gritty code-writing to just arrange data so that hour 'i' really precedes 'i+1' in memory, time which could be used more productively addressing the scientific problem itself.

In addition, the size of an SSB file is "very small" for today's computers (somewhat less than 9 megabytes for data sampled at 10 Hz), and in the same time "large enough" to allow fast data transfer rates on local and network channels. Also, adopting daily files instead of hourly allow users to deal with 24 time less files, a strong bonus in operating systems placing penalties to large data file counts (as the author knows, Microsoft Windows _was_ prone to this problems in the past; and anyway, anyone who tried to list a some-years data set organized hourly on an FTP connection while counting time to gather children after school knows very well which the consequence of a "many extremely small files" approach means - a little crudelty, imposed by technological constraints in last century Nineties, but no longer needed in 2023).

## Relevant acronyms and terminology

- SSB (to be not confused with "single-side-band" in radio transmission technology) means "Simple ultraSonic Binary", and is a file storage convention. The author uses it as a sort-of adjective applied to files.

- SSBF stays for "Simple ultraSonic Binary Format", used as a substantive.

So we can say that specific file "is SSB", while "this specification refers to SSBF". Occasionally the author might use a longer version of the latter by writing or saying something like "this file is encoded in SSB format".

Note from the author: I don't like specially acronyms, but this one was quite a necessity, given its expansion being really very long and quite annoying; I hope "SSB" and "SSBF" are reasonably easy to remember, and am open to adopt any better idea. Of course I'm aware the acronym SSB overlaps another well-known object in communications engineering.

## What's inside this repository

In this repository you can find two things:

- A _specification_ of SSBF format. You are free to consider it as the _main_ repository contents, and can find it further on in this document.

- An example, "reference" implementation of a library for importing, reading and writing SSB files.

The reference implementation, in directory "/src" of this repo, is written in Fortran 2008, assuming use of GNU Fortran or Intel Fortran compilers on a little-endian architecture. It could have been written in any other programming language providing access to binary data (e.g. C/C++, D, Julia, Python, ...), but the author choice was modern Fortran, due to its wide use in meteorology and fluid dynamics communities, code simplicity to the eyes of non-professional programmers and (not last) because of her own relative proficiency with that language.

It is not excluded other (non-reference) implementations will be made available in future. And besides, would any of you want to contribute a version you can contribute to the code base, or fork the repository. The initiative is _open_, and participation is free, also thanks the permissive MIT license under which the code is distributed.

## Availability of data in SSB form

As of the publication date of this readme file, 23 February 2023, the author knows a significant sample of SSB data encoding is under way by the met unit of ARPA Lombardia for stations of their SHAKEUP micro-meteorological network, and will be available upon request as soon as the encoding is complete. The data set amounts in some tens of gigabytes.

## Standardization

Contacts with other institutions is in progress across Europe. Although not (yet) an official standard, effort is ongoing to allow an easy interchange of minimally-sized ultrasonic anemometer data among users. Would interest grow enough the author, who is actually an IEEE member, will evaluate whether to submit the SSBF as a standard proposal to the IEEE board. Your support (coding/documenting/testing if possible, but also emotionally is welcome) and sign of interest is essential in this way.

## SSB format file naming convention

The name of data files in SSBF cannot be assigned at will, but must conform to the specification YYYY-MM-DD.ssb, where YYYY represents the year, MM the month number, and DD the day number. The extension ".ssb" is nominal and mandatory.

Example:

2012-03-08.ssb

No restriction whatsoever is imposed on the directory an SSB file is stored in: SSB files can be copied, moved, compressed, used, freely.

## Known limitations and wishful desires for future

This specification refers to SSB _version 1.0_, which is limited to _ultrasonic anemometer quadruples_ each containing the three components of wind vector and the 

## Format description

### Byte-endianness

SSB files are stored in _little-endian_ form.

This is the native byte endianness on Intel, AMD and ARM architectures. As far the author knows, some other widely diffused processors are big-endian (PowerPC among them). Interoperability has been tested between a Hewlett-Packard Z20 workstation (Intel Xeon) and an Apple MacBook Pro (M1 silicon, a 64-bit ARM incarnation), by direct file transfer and read.

If using a big-endian architecture, the "open" statement acting on SSB files should be changed to specify little-endian form explicitly. This should be possible as the author knows on various compilers, but actual mode and syntax may vary. A cruder alternative, that is reading the whole data byte-wise and then converting to the appropriate local byte endianness, is also possible - the author preferred not using it in her "reference" implementation in sake of code clarity.

### Data sequence

